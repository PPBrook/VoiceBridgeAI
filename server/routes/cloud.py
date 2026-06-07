"""Cloud provider configuration routes."""

from __future__ import annotations

import asyncio

from fastapi import APIRouter, Body

from app_bootstrap import preload_after_provider_test, preload_translate
from config.asr_config import get_status as get_asr_status, normalize_mode
from config.cloud_config import apply_cloud, cloud_status, test_all_and_verify, test_and_verify
from config.engine_config import apply_settings, get_engine_status
from config.revise_config import get_status as get_revise_status, normalize_mode as normalize_revise_mode
import core.local_models as local_models
from core.local_models import get_status as get_local_models_status
from providers.whisper_asr import load_model as load_whisper

router = APIRouter()


@router.get("/api/cloud/settings")
def get_cloud_settings():
    return {"ok": True, **cloud_status()}


@router.post("/api/cloud/test")
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
        await preload_after_provider_test(layer, provider_id)
    return {
        "ok": ok,
        "message": message,
        **get_asr_status(),
        **get_engine_status(),
        **get_revise_status(),
        **cloud_status(),
    }


@router.post("/api/cloud/test-all")
async def post_cloud_test_all(payload: dict = Body(default_factory=dict)):
    results, summary = await asyncio.to_thread(test_all_and_verify, payload or None)
    for item in results:
        if item.get("ok"):
            await preload_after_provider_test(
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


@router.get("/api/cloud/ui-prefs")
def get_cloud_ui_prefs():
    from config.cloud_ui_prefs import ui_prefs_status

    return {"ok": True, **ui_prefs_status()}


@router.post("/api/cloud/ui-prefs")
async def post_cloud_ui_prefs(payload: dict = Body(default_factory=dict)):
    from config.cloud_ui_prefs import save_hidden_providers, ui_prefs_status

    raw = payload.get("hiddenProviders")
    ids = [str(x).strip() for x in raw] if isinstance(raw, list) else []
    save_hidden_providers(ids)
    return {"ok": True, **ui_prefs_status()}


@router.post("/api/cloud/settings")
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
    await preload_translate(payload)
    return {
        "ok": True,
        **get_asr_status(asr_mode),
        **get_engine_status(),
        **get_revise_status(rv_mode),
        **cloud_status(),
        **get_local_models_status(),
    }
