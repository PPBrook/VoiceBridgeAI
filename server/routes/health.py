"""Health and index routes."""

from __future__ import annotations

from fastapi import APIRouter

from app_bootstrap import FEATURES, startup_test_status
from config.asr_config import get_status as get_asr_status
from config.cloud_config import cloud_status
from config.engine_config import get_engine_status
from config.revise_config import get_status as get_revise_status
from core.local_model_jobs import get_active_download, job_public_view
from core.local_models import get_status as get_local_models_status

router = APIRouter()


@router.get("/api/health")
def health():
    payload = {
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
    active = get_active_download()
    if active:
        payload["activeDownload"] = job_public_view(active)
    return payload


@router.get("/")
def index():
    return {
        "ok": True,
        "name": "VoiceBridgeAI",
        "message": "API server — use macOS desktop app",
        "health": "/api/health",
        "ws": "/ws",
    }
