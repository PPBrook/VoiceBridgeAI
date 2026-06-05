"""VoiceBridgeAI — tab capture, WebSocket PCM, Whisper ASR."""

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from asr import PcmBuffer, load_model, transcribe

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "static"

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

CHUNK_SECONDS = 2.5

FEATURES = [
    "static-page",
    "health-api",
    "tab-capture",
    "websocket-pcm",
    "asr-whisper-en",
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
        "pr": 4,
        "features": FEATURES,
    }


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 48000
    buffer = PcmBuffer()
    transcribing = False
    log.info("client connected")

    async def run_asr() -> None:
        nonlocal transcribing
        if transcribing or buffer.duration(sample_rate) < CHUNK_SECONDS:
            return
        transcribing = True
        pcm = buffer.drain()
        try:
            text = await asyncio.to_thread(transcribe, pcm, sample_rate)
            if text:
                await ws.send_json({"type": "asr", "text": text})
                log.info("asr: %s", text)
        except Exception as exc:
            log.exception("asr failed: %s", exc)
        finally:
            transcribing = False

    try:
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                break

            if "text" in msg and msg["text"]:
                data = json.loads(msg["text"])
                if data.get("type") == "config":
                    sample_rate = int(data.get("sampleRate", 48000))
                    log.info("config sampleRate=%s", sample_rate)

            if "bytes" in msg and msg["bytes"]:
                buffer.append(msg["bytes"])
                await run_asr()

    except WebSocketDisconnect:
        pass
    finally:
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
