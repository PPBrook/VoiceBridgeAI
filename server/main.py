"""VoiceBridgeAI — tab capture, PCM, ASR (Tencent / local), translate."""

import asyncio
import json
import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Body, FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from asr_config import default_mode, get_status as get_asr_status, normalize_mode
from pcm import PcmFramer, resample_to_16k
from tencent_asr import TencentAsrStream, configured as tencent_configured
from translate import translate as translate_zh
from vad import UtteranceEngine
from whisper_asr import load_model as load_whisper

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "static"


def _load_env_file() -> None:
    import os

    env_path = ROOT / ".env"
    if not env_path.is_file():
        return
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'\"")
        if key and key not in os.environ:
            os.environ[key] = value


_load_env_file()

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

FEATURES = [
    "static-page",
    "health-api",
    "tab-capture",
    "websocket-pcm",
    "asr-tencent-stream",
    "asr-whisper-local",
    "asr-settings",
    "utterance-vad",
    "translate-zh",
]


@asynccontextmanager
async def lifespan(_app: FastAPI):
    mode = default_mode()
    log.info("default ASR mode: %s", mode)
    if mode == "local" or not tencent_configured():
        await asyncio.to_thread(load_whisper)
    yield


app = FastAPI(title="VoiceBridgeAI", version="0.1.0", lifespan=lifespan)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "pr": 8,
        "features": FEATURES,
        **get_asr_status(),
    }


@app.post("/api/asr/settings")
async def asr_settings(payload: dict = Body(...)):
    mode = normalize_mode(payload.get("asrMode"))
    status = get_asr_status(mode)
    if mode == "local":
        await asyncio.to_thread(load_whisper)
    return {"ok": True, **status}


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 48000
    asr_mode = default_mode()
    alive = True
    tencent: TencentAsrStream | None = None
    engine: UtteranceEngine | None = None
    framer = PcmFramer()
    pipeline_lock = asyncio.Lock()
    translate_lock = asyncio.Lock()
    log.info("client connected")

    def mark_dead() -> None:
        nonlocal alive
        alive = False

    async def send_json(payload: dict) -> bool:
        if not alive:
            return False
        try:
            await ws.send_json(payload)
            return True
        except Exception:
            mark_dead()
            return False

    async def emit_local(seg_id: int, pcm: bytes) -> None:
        from whisper_asr import transcribe

        if not alive:
            return
        async with pipeline_lock:
            text = await asyncio.to_thread(transcribe, pcm, sample_rate)
            if not text or not alive:
                return
            await send_json(
                {
                    "type": "asr",
                    "segmentId": seg_id,
                    "text": text,
                    "translation": "",
                    "partial": False,
                    "final": False,
                }
            )
        async with translate_lock:
            zh = await asyncio.to_thread(translate_zh, text)
        if not alive:
            return
        await send_json(
            {
                "type": "asr",
                "segmentId": seg_id,
                "text": text,
                "translation": zh,
                "partial": False,
                "final": True,
            }
        )
        log.info("segment %d [local]: %s → %s", seg_id, text, zh)

    async def handle_tencent(index: int, text: str, is_final: bool) -> None:
        if not alive or not text:
            return
        if is_final:
            async with translate_lock:
                zh = await asyncio.to_thread(translate_zh, text)
            if not alive:
                return
            await send_json(
                {
                    "type": "asr",
                    "segmentId": index,
                    "text": text,
                    "translation": zh,
                    "partial": False,
                    "final": True,
                }
            )
            log.info("segment %d [tencent final]: %s → %s", index, text, zh)
        else:
            await send_json(
                {
                    "type": "asr",
                    "segmentId": index,
                    "text": text,
                    "translation": "",
                    "partial": True,
                    "final": False,
                }
            )

    async def start_asr(mode: str) -> bool:
        nonlocal tencent, engine, framer, asr_mode
        asr_mode = normalize_mode(mode)
        framer = PcmFramer()
        if tencent:
            await tencent.close()
            tencent = None
        engine = None

        if asr_mode == "tencent":
            if not tencent_configured():
                await send_json(
                    {
                        "type": "error",
                        "message": "腾讯云 ASR 未配置，请选「本地 Whisper」或在 .env 填入密钥",
                    }
                )
                return False
            tencent = TencentAsrStream(handle_tencent)
            try:
                await tencent.start()
            except Exception as exc:
                log.exception("tencent asr start failed")
                await tencent.close()
                tencent = None
                await send_json(
                    {
                        "type": "error",
                        "message": f"腾讯云 ASR 连接失败: {exc}",
                    }
                )
                return False
        else:
            await asyncio.to_thread(load_whisper)
            engine = UtteranceEngine(sample_rate)
        await send_json({"type": "asrReady", **get_asr_status(asr_mode)})
        log.info("asr ready mode=%s sampleRate=%s", asr_mode, sample_rate)
        return True

    try:
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                mark_dead()
                break

            if "text" in msg and msg["text"]:
                data = json.loads(msg["text"])
                if data.get("type") == "config":
                    sample_rate = int(data.get("sampleRate", 48000))
                    mode = data.get("asrMode", asr_mode)
                    if engine:
                        engine.reset(sample_rate)
                    ok = await start_asr(mode)
                    if not ok:
                        mark_dead()
                        break

            if "bytes" in msg and msg["bytes"]:
                if not alive:
                    continue
                if asr_mode == "tencent":
                    if tencent is None:
                        continue
                    pcm16 = resample_to_16k(msg["bytes"], sample_rate)
                    for frame in framer.push(pcm16):
                        await tencent.send_pcm(frame)
                elif engine is not None:
                    result = engine.feed(msg["bytes"])
                    if result:
                        seg_id, pcm = result
                        asyncio.create_task(emit_local(seg_id, pcm))

    except WebSocketDisconnect:
        mark_dead()
    finally:
        mark_dead()
        if tencent:
            tail = framer.flush()
            if tail:
                try:
                    await tencent.send_pcm(tail)
                except Exception:
                    pass
            await tencent.close()
        if engine:
            flushed = engine.flush()
            if flushed and alive:
                seg_id, pcm = flushed
                await emit_local(seg_id, pcm)
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
