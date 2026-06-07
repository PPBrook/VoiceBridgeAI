"""Engine / ASR / translate settings routes."""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Body

from app_bootstrap import preload_translate
from config.asr_config import get_status as get_asr_status, normalize_mode
from config.cloud_config import cloud_status
from config.engine_config import apply_settings, get_engine_status
from config.revise_config import get_status as get_revise_status, normalize_mode as normalize_revise_mode
import core.local_models as local_models
from core.local_models import get_status as get_local_models_status
from providers.whisper_asr import load_model as load_whisper

router = APIRouter()


async def engine_settings(payload: dict):
    apply_settings(payload)
    asr_mode = normalize_mode(payload.get("asrProvider") or payload.get("asrMode"))
    rv_mode = normalize_revise_mode(payload.get("reviseMode"))
    if asr_mode == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
    await preload_translate(payload)
    return {
        "ok": True,
        **get_asr_status(asr_mode),
        **get_engine_status(),
        **get_revise_status(rv_mode),
        **cloud_status(),
        **get_local_models_status(),
    }


@router.post("/api/engine/settings")
async def post_engine_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@router.post("/api/asr/settings")
async def post_asr_settings(payload: dict = Body(...)):
    return await engine_settings(payload)


@router.post("/api/translate/settings")
async def post_translate_settings(payload: dict = Body(...)):
    return await engine_settings(payload)
