"""VoiceBridgeAI — tab capture, PCM, ASR (Tencent / local), translate, revise."""

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
from revise import ReviseScheduler
from tencent_asr import TencentAsrStream, configured as tencent_configured
from translate import translate_final, translate_partial
from translate_config import default_mode as default_translate_mode
from translate_config import get_status as get_translate_config_status
from translate_config import normalize_mode as normalize_translate_mode
from vad import ReviseEngine
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


async def _preload_translate(tr_mode: str) -> None:
    tr_mode = normalize_translate_mode(tr_mode)
    if tr_mode == "argos":
        from translate_argos import load_model as load_argos

        await asyncio.to_thread(load_argos)
    elif tr_mode == "opus":
        from translate_opus import load_model as load_opus

        await asyncio.to_thread(load_opus)


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
    "translate-dual-engine",
    "translate-settings",
    "translate-offline",
    "subtitle-revise",
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
        "pr": 10,
        "features": FEATURES,
        **get_asr_status(),
        **get_translate_config_status(),
    }


@app.post("/api/engine/settings")
async def engine_settings(payload: dict = Body(...)):
    asr_mode = normalize_mode(payload.get("asrMode"))
    tr_mode = normalize_translate_mode(payload.get("translateMode"))
    if asr_mode == "local":
        await asyncio.to_thread(load_whisper)
    await _preload_translate(tr_mode)
    return {
        "ok": True,
        **get_asr_status(asr_mode),
        **get_translate_config_status(tr_mode),
    }


@app.post("/api/asr/settings")
async def asr_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@app.post("/api/translate/settings")
async def translate_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 48000
    asr_mode = default_mode()
    translate_mode = default_translate_mode()
    alive = True
    tencent: TencentAsrStream | None = None
    engine: ReviseEngine | None = None
    framer = PcmFramer()
    local_tasks: dict[int, asyncio.Task] = {}
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

    def bind_revise(mode: str) -> ReviseScheduler:
        m = normalize_translate_mode(mode)

        def partial_fn(text: str) -> str:
            return translate_partial(text, m)

        def final_fn(text: str, draft: str | None) -> str:
            return translate_final(text, draft, m)

        return ReviseScheduler(partial_fn, final_fn, send_json)

    revise = bind_revise(translate_mode)

    def cancel_local_task(seg_id: int) -> None:
        task = local_tasks.pop(seg_id, None)
        if task and not task.done():
            task.cancel()

    async def run_local(seg_id: int, pcm: bytes, *, final: bool) -> None:
        from whisper_asr import transcribe

        try:
            if not alive:
                return
            text = await asyncio.to_thread(transcribe, pcm, sample_rate)
            if not text or not alive:
                return
            if final:
                await revise.finalize(seg_id, text)
                log.info("segment %d [local final]: %s", seg_id, text)
            else:
                await revise.emit_english(seg_id, text, partial=True, final=False)
                await revise.schedule_partial_translation(seg_id, text)
                log.info("segment %d [local refine]: %s", seg_id, text)
        except asyncio.CancelledError:
            raise
        except Exception:
            log.exception("local refine failed seg=%s", seg_id)

    def schedule_local(seg_id: int, pcm: bytes, *, final: bool) -> None:
        cancel_local_task(seg_id)
        local_tasks[seg_id] = asyncio.create_task(run_local(seg_id, pcm, final=final))

    async def handle_tencent(index: int, text: str, is_final: bool) -> None:
        if not alive or not text:
            return
        if is_final:
            await revise.finalize(index, text)
            log.info("segment %d [tencent final]: %s", index, text)
        else:
            await revise.emit_english(index, text, partial=True, final=False)
            await revise.schedule_partial_translation(index, text)

    async def start_asr(mode: str, tr_mode: str | None = None) -> bool:
        nonlocal tencent, engine, framer, asr_mode, translate_mode, revise
        asr_mode = normalize_mode(mode)
        if tr_mode is not None:
            translate_mode = normalize_translate_mode(tr_mode)
        framer = PcmFramer()
        revise.clear()
        revise = bind_revise(translate_mode)
        for seg_id in list(local_tasks):
            cancel_local_task(seg_id)
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
            engine = ReviseEngine(sample_rate)
        await _preload_translate(translate_mode)
        await send_json(
            {
                "type": "asrReady",
                **get_asr_status(asr_mode),
                **get_translate_config_status(translate_mode),
            }
        )
        log.info(
            "asr ready mode=%s translate=%s sampleRate=%s",
            asr_mode,
            translate_mode,
            sample_rate,
        )
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
                    tr_mode = data.get("translateMode", translate_mode)
                    if engine:
                        engine.reset(sample_rate)
                    ok = await start_asr(mode, tr_mode)
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
                    for kind, seg_id, pcm in engine.feed(msg["bytes"]):
                        schedule_local(
                            seg_id,
                            pcm,
                            final=(kind == "final"),
                        )

    except WebSocketDisconnect:
        mark_dead()
    finally:
        mark_dead()
        revise.clear()
        for seg_id in list(local_tasks):
            cancel_local_task(seg_id)
        if tencent:
            tail = framer.flush()
            if tail:
                try:
                    await tencent.send_pcm(tail)
                except Exception:
                    pass
            await tencent.close()
        if engine:
            for kind, seg_id, pcm in engine.flush():
                if alive:
                    await run_local(seg_id, pcm, final=(kind == "final"))
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
