"""VoiceBridgeAI — tab capture, PCM, multi-provider ASR / translate / revise."""

import asyncio
import contextlib
import json
import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Body, FastAPI, WebSocket, WebSocketDisconnect

from config.cloud_config import apply_cloud, cloud_status, test_all_and_verify, test_and_verify
from config.asr_config import default_mode, get_status as get_asr_status, normalize_mode
from config.engine_config import apply_settings, get_engine_status
from core.pcm import PcmFramer, resample_to_16k
from core.revise import ReviseScheduler
from config.revise_config import default_mode as default_revise_mode
from config.revise_config import get_params as get_revise_params
from config.revise_config import get_status as get_revise_status
from config.revise_config import normalize_mode as normalize_revise_mode
from providers.tencent_asr import TencentAsrStream, configured as tencent_configured
from core.translate import translate_final, translate_partial
from core.vad import ReviseEngine
from providers.whisper_asr import load_model as load_whisper
from core.local_models import get_status as get_local_models_status
import core.local_models as local_models

from config.app_paths import env_file_path


def _load_env_file() -> None:
    import os

    env_path = env_file_path()
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


async def _preload_translate(payload: dict | None = None) -> None:
    from config.final_config import normalize_provider as normalize_final
    from config.partial_config import normalize_provider as normalize_partial

    partial = normalize_partial(
        payload.get("partialProvider") if payload else None
    )
    final = normalize_final(payload.get("finalProvider") if payload else None)
    if partial == "argos" or final == "argos":
        if not local_models.optional_local_models_enabled() or local_models.is_argos_installed():
            from providers.translate_argos import load_model as load_argos

            await asyncio.to_thread(load_argos)


FEATURES = [
    "health-api",
    "websocket-pcm",
    "asr-multi",
    "translate-dual-engine",
    "cloud-config",
    "local-models-optional",
    "subtitle-revise",
]


_startup_test: dict = {"running": False, "done": False, "summary": None, "results": []}


def startup_test_status() -> dict:
    return dict(_startup_test)


async def _preload_after_provider_test(layer: str, provider_id: str) -> None:
    if layer == "asr" and provider_id == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
        return
    if layer in ("partial", "final") and provider_id == "argos":
        if not local_models.optional_local_models_enabled() or local_models.is_argos_installed():
            from providers.translate_argos import load_model

            await asyncio.to_thread(load_model)


async def _run_startup_tests() -> None:
    global _startup_test
    if os.getenv("AUTO_TEST_ON_START", "1").strip().lower() in ("0", "false", "no", "off"):
        _startup_test = {
            "running": False,
            "done": True,
            "summary": "已跳过启动测试（AUTO_TEST_ON_START=0）",
            "results": [],
        }
        return
    _startup_test = {"running": True, "done": False, "summary": "正在测试已配置且未隐藏的接口…", "results": []}
    try:
        results, summary = await asyncio.to_thread(test_all_and_verify, None)
        for item in results:
            if item.get("ok"):
                await _preload_after_provider_test(
                    str(item["layer"]),
                    str(item["providerId"]),
                )
        _startup_test = {
            "running": False,
            "done": True,
            "summary": summary,
            "results": results,
        }
        log.info("startup test-all: %s", summary)
    except Exception:
        log.exception("startup test-all failed")
        _startup_test = {
            "running": False,
            "done": True,
            "summary": "启动测试异常",
            "results": [],
        }


@asynccontextmanager
async def lifespan(_app: FastAPI):
    mode = normalize_mode(default_mode())
    log.info("default ASR mode: %s", mode)
    if mode == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
    startup_task = asyncio.create_task(_run_startup_tests())
    yield
    startup_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await startup_task


app = FastAPI(title="VoiceBridgeAI", version="0.1.0", lifespan=lifespan)


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "pr": 10,
        "features": FEATURES,
        **get_asr_status(),
        **get_engine_status(),
        **get_revise_status(),
        **cloud_status(),
        **get_local_models_status(),
        "startupTest": startup_test_status(),
    }


@app.get("/api/models/local")
def get_local_models():
    return {"ok": True, **get_local_models_status()}


@app.post("/api/models/local/download")
async def post_local_model_download(payload: dict = Body(default_factory=dict)):
    model_id = (payload.get("id") or "").strip()
    whisper_model = (payload.get("whisperModel") or "").strip() or None
    if not model_id:
        return {"ok": False, "message": "缺少 id（whisper 或 argos）", **get_local_models_status()}
    try:
        await asyncio.to_thread(
            local_models.download,
            model_id,
            whisper_model=whisper_model,
        )
        if model_id == "whisper" and whisper_model:
            os.environ["WHISPER_MODEL"] = whisper_model
            from config.env_persist import persist_local_model_settings

            persist_local_model_settings({"whisperModel": whisper_model})
            from providers.whisper_asr import unload_model

            unload_model()
        return {
            "ok": True,
            "message": "下载完成",
            **get_local_models_status(),
            **get_asr_status(),
            **get_engine_status(),
        }
    except Exception as exc:
        log.exception("local model download failed: %s", model_id)
        return {"ok": False, "message": str(exc), **get_local_models_status()}


@app.post("/api/models/local/settings")
async def post_local_model_settings(payload: dict = Body(default_factory=dict)):
    try:
        await asyncio.to_thread(local_models.apply_local_model_settings, payload)
        return {
            "ok": True,
            "message": "本地模型设置已保存",
            **get_local_models_status(),
            **get_asr_status(),
            **get_engine_status(),
        }
    except Exception as exc:
        log.exception("local model settings failed")
        return {"ok": False, "message": str(exc), **get_local_models_status()}


@app.post("/api/models/local/delete")
async def post_local_model_delete(payload: dict = Body(default_factory=dict)):
    model_id = (payload.get("id") or "").strip()
    whisper_model = (payload.get("whisperModel") or "").strip() or None
    if not model_id:
        return {"ok": False, "message": "缺少 id（whisper 或 argos）", **get_local_models_status()}
    try:
        await asyncio.to_thread(local_models.uninstall, model_id, whisper_model=whisper_model)
        return {
            "ok": True,
            "message": "已删除",
            **get_local_models_status(),
            **get_asr_status(),
            **get_engine_status(),
        }
    except Exception as exc:
        log.exception("local model delete failed: %s", model_id)
        return {"ok": False, "message": str(exc), **get_local_models_status()}


@app.get("/api/cloud/settings")
def get_cloud_settings():
    return {"ok": True, **cloud_status()}


@app.post("/api/cloud/test")
async def post_cloud_test(payload: dict = Body(...)):
    layer = (payload.get("layer") or "").strip()
    provider_id = (payload.get("providerId") or payload.get("provider") or "").strip()
    if not layer or not provider_id:
        return {
            "ok": False,
            "message": "缺少 layer 或 providerId",
            **cloud_status(),
        }
    ok, message = await asyncio.to_thread(test_and_verify, layer, provider_id, payload)
    if ok:
        await _preload_after_provider_test(layer, provider_id)
    return {
        "ok": ok,
        "message": message,
        **get_asr_status(),
        **get_engine_status(),
        **get_revise_status(),
        **cloud_status(),
    }


@app.post("/api/cloud/test-all")
async def post_cloud_test_all(payload: dict = Body(default_factory=dict)):
    results, summary = await asyncio.to_thread(test_all_and_verify, payload or None)
    for item in results:
        if item.get("ok"):
            await _preload_after_provider_test(
                str(item["layer"]),
                str(item["providerId"]),
            )
    passed = sum(1 for item in results if item.get("ok"))
    failed = len(results) - passed
    return {
        "ok": failed == 0 and bool(results),
        "message": summary,
        "results": results,
        "passed": passed,
        "failed": failed,
        **get_asr_status(),
        **get_engine_status(),
        **get_revise_status(),
        **cloud_status(),
    }


@app.get("/api/cloud/ui-prefs")
def get_cloud_ui_prefs():
    from config.cloud_ui_prefs import ui_prefs_status

    return {"ok": True, **ui_prefs_status()}


@app.post("/api/cloud/ui-prefs")
async def post_cloud_ui_prefs(payload: dict = Body(default_factory=dict)):
    from config.cloud_ui_prefs import save_hidden_providers, ui_prefs_status

    raw = payload.get("hiddenProviders")
    ids = [str(x).strip() for x in raw] if isinstance(raw, list) else []
    save_hidden_providers(ids)
    return {"ok": True, **ui_prefs_status()}


@app.post("/api/cloud/settings")
async def post_cloud_settings(payload: dict = Body(...)):
    errors = apply_cloud(payload)
    if errors:
        return {
            "ok": False,
            "errors": errors,
            **cloud_status(),
        }
    apply_settings(payload)
    asr_mode = normalize_mode(payload.get("asrProvider") or payload.get("asrMode"))
    rv_mode = normalize_revise_mode(payload.get("reviseMode"))
    if asr_mode == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
    await _preload_translate(payload)
    return {
        "ok": True,
        **get_asr_status(asr_mode),
        **get_engine_status(),
        **get_revise_status(rv_mode),
        **cloud_status(),
        **get_local_models_status(),
    }


@app.post("/api/engine/settings")
async def engine_settings(payload: dict = Body(...)):
    apply_settings(payload)
    asr_mode = normalize_mode(payload.get("asrProvider") or payload.get("asrMode"))
    rv_mode = normalize_revise_mode(payload.get("reviseMode"))
    if asr_mode == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
    await _preload_translate(payload)
    return {
        "ok": True,
        **get_asr_status(asr_mode),
        **get_engine_status(),
        **get_revise_status(rv_mode),
        **cloud_status(),
        **get_local_models_status(),
    }


@app.post("/api/asr/settings")
async def asr_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@app.post("/api/translate/settings")
async def translate_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@app.get("/")
def index():
    return {
        "ok": True,
        "name": "VoiceBridgeAI",
        "message": "API server — use macOS desktop app",
        "health": "/api/health",
        "ws": "/ws",
    }


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 48000
    asr_mode = default_mode()
    revise_mode = default_revise_mode()
    revise_params = get_revise_params(revise_mode)
    alive = True
    tencent: TencentAsrStream | None = None
    engine: ReviseEngine | None = None
    framer = PcmFramer()
    local_tasks: dict[int, asyncio.Task] = {}
    tencent_pcm_acc = bytearray()
    tencent_sample_rate = 16000
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

    def bind_revise(params) -> ReviseScheduler:
        return ReviseScheduler(
            translate_partial,
            translate_final,
            send_json,
            params,
        )

    revise = bind_revise(revise_params)

    def cancel_local_task(seg_id: int) -> None:
        task = local_tasks.pop(seg_id, None)
        if task and not task.done():
            task.cancel()

    async def run_local(seg_id: int, pcm: bytes, *, final: bool) -> None:
        try:
            if not alive:
                return
            if asr_mode == "openai":
                from providers.openai_asr import transcribe as cloud_transcribe
            else:
                from providers.whisper_asr import transcribe as cloud_transcribe

            text = await asyncio.to_thread(cloud_transcribe, pcm, sample_rate)
            if not text or not alive:
                return
            if final:
                revise.attach_pcm(seg_id, pcm, sample_rate)
                await revise.finalize(seg_id, text)
                await revise.run_lookback(seg_id)
                log.info("segment %d [local final]: %s", seg_id, text)
            else:
                revise.attach_pcm(seg_id, pcm, sample_rate)
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
        nonlocal tencent_pcm_acc
        if not alive or not text:
            return
        if is_final:
            if tencent_pcm_acc:
                revise.attach_pcm(index, bytes(tencent_pcm_acc), tencent_sample_rate)
                tencent_pcm_acc.clear()
            await revise.finalize(index, text)
            await revise.run_lookback(index)
            log.info("segment %d [tencent final]: %s", index, text)
        else:
            await revise.emit_english(index, text, partial=True, final=False)
            await revise.schedule_partial_translation(index, text)

    async def start_asr(
        mode: str,
        rv_mode: str | None = None,
    ) -> bool:
        nonlocal tencent, engine, framer, asr_mode, revise_mode, revise_params, revise, tencent_pcm_acc
        asr_mode = normalize_mode(mode)
        if rv_mode is not None:
            revise_mode = normalize_revise_mode(rv_mode)
        revise_params = get_revise_params(revise_mode)
        framer = PcmFramer()
        tencent_pcm_acc.clear()
        revise.clear()
        revise = bind_revise(revise_params)
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
                        "message": "腾讯云 ASR 未配置，请选其他识别方式或在 API 配置填写密钥",
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
        elif asr_mode == "openai":
            from providers.openai_asr import configured as openai_ok

            if not openai_ok():
                await send_json(
                    {
                        "type": "error",
                        "message": "OpenAI ASR 未配置，请填写 OpenAI API Key",
                    }
                )
                return False
            engine = ReviseEngine(sample_rate, revise_params.refine_interval_s)
        else:
            if local_models.optional_local_models_enabled() and not local_models.is_whisper_installed():
                await send_json(
                    {
                        "type": "error",
                        "message": "Whisper 未安装。请在设置 → 本地模型 中下载，或改用云端 ASR。",
                    }
                )
                return False
            await asyncio.to_thread(load_whisper)
            engine = ReviseEngine(sample_rate, revise_params.refine_interval_s)
        await _preload_translate(None)
        await send_json(
            {
                "type": "asrReady",
                **get_asr_status(asr_mode),
                **get_engine_status(),
                **get_revise_status(revise_mode),
            }
        )
        from config.partial_config import normalize_provider as np
        from config.final_config import normalize_provider as nf

        log.info(
            "asr ready asr=%s partial=%s final=%s revise=%s sampleRate=%s",
            asr_mode,
            np(None),
            nf(None),
            revise_mode,
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
                    apply_settings(data)
                    sample_rate = int(data.get("sampleRate", 48000))
                    mode = data.get("asrProvider") or data.get("asrMode", asr_mode)
                    rv_mode = data.get("reviseMode", revise_mode)
                    pending = get_revise_params(rv_mode)
                    if engine:
                        engine.reset(sample_rate, pending.refine_interval_s)
                    ok = await start_asr(mode, rv_mode)
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
                    tencent_pcm_acc.extend(pcm16)
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


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("VOICEBRIDGE_PORT", "8765"))
    print(f"VoiceBridgeAI — http://127.0.0.1:{port}")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        ws_ping_interval=20,
        ws_ping_timeout=120,
    )
