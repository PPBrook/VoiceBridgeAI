"""VoiceBridgeAI — tab capture, WebSocket PCM, VAD, Whisper ASR."""

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from asr import load_model, transcribe
from translate import translate as translate_zh
from vad import UtteranceEngine

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "static"

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

FEATURES = [
    "static-page",
    "health-api",
    "tab-capture",
    "websocket-pcm",
    "asr-whisper-en",
    "utterance-vad",
    "translate-zh",
]


@asynccontextmanager
async def lifespan(_app: FastAPI):
    load_model()
    yield


app = FastAPI(title="VoiceBridgeAI", version="0.1.0", lifespan=lifespan)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "pr": 6,
        "features": FEATURES,
    }


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 48000
    engine = UtteranceEngine(sample_rate)
    transcribe_lock = asyncio.Lock()
    log.info("client connected")

    async def send_segment(seg_id: int, pcm: bytes) -> None:
        async with transcribe_lock:
            try:
                text = await asyncio.to_thread(transcribe, pcm, sample_rate)
                if text:
                    zh = await asyncio.to_thread(translate_zh, text)
                    await ws.send_json(
                        {
                            "type": "asr",
                            "segmentId": seg_id,
                            "text": text,
                            "translation": zh,
                            "final": True,
                        }
                    )
                    log.info("segment %d: %s → %s", seg_id, text, zh)
            except Exception as exc:
                log.exception("asr failed segment %d: %s", seg_id, exc)

    try:
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                break

            if "text" in msg and msg["text"]:
                data = json.loads(msg["text"])
                if data.get("type") == "config":
                    sample_rate = int(data.get("sampleRate", 48000))
                    engine.reset(sample_rate)
                    log.info("config sampleRate=%s", sample_rate)

            if "bytes" in msg and msg["bytes"]:
                result = engine.feed(msg["bytes"])
                if result:
                    seg_id, pcm = result
                    asyncio.create_task(send_segment(seg_id, pcm))

    except WebSocketDisconnect:
        pass
    finally:
        flushed = engine.flush()
        if flushed:
            seg_id, pcm = flushed
            await send_segment(seg_id, pcm)
        log.info("client disconnected")


app.mount("/static", StaticFiles(directory=STATIC), name="static")


if __name__ == "__main__":
    import uvicorn

    print("VoiceBridgeAI — http://127.0.0.1:8765")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8765,
        reload=False,
        ws_ping_interval=20,
        ws_ping_timeout=120,
    )
