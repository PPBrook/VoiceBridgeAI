"""WebSocket PCM streaming session."""

from __future__ import annotations

import asyncio
import json
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app_bootstrap import preload_translate
from config.asr_config import default_mode, get_status as get_asr_status, normalize_mode
from config.engine_config import apply_settings, get_engine_status
from config.revise_config import default_mode as default_revise_mode
from config.revise_config import get_params as get_revise_params
from config.revise_config import get_status as get_revise_status
from config.revise_config import normalize_mode as normalize_revise_mode
from core.pcm import PcmFramer, resample_to_16k
from core.revise import ReviseScheduler
from core.revise_context import set_revise_mode
from core.translate import translate_final, translate_partial
from core.vad import ReviseEngine
import core.local_models as local_models
from providers.tencent_asr import TencentAsrStream, configured as tencent_configured
from providers.whisper_asr import load_model as load_whisper

router = APIRouter()
log = logging.getLogger(__name__)


@router.websocket("/ws")
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

    def bind_revise(params, mode: str) -> ReviseScheduler:
        set_revise_mode(mode)
        return ReviseScheduler(
            translate_partial,
            translate_final,
            send_json,
            params,
        )

    revise = bind_revise(revise_params, revise_mode)

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
        revise = bind_revise(revise_params, revise_mode)
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
            engine = ReviseEngine(sample_rate, revise_params.vad_params())
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
            engine = ReviseEngine(sample_rate, revise_params.vad_params())
        await preload_translate(None)
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
                        engine.reset(sample_rate, pending.vad_params())
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
