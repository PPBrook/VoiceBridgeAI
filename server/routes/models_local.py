"""Local model HTTP routes."""

from __future__ import annotations

import asyncio
import logging

from fastapi import APIRouter, Body

from config.asr_config import get_status as get_asr_status
from config.engine_config import get_engine_status
import core.local_models as local_models
from core.local_model_jobs import get_active_download, get_job, job_public_view, start_download
from core.local_models import get_status as get_local_models_status

router = APIRouter()
log = logging.getLogger(__name__)


@router.get("/api/models/local")
def get_local_models():
    return {"ok": True, **get_local_models_status()}


@router.post("/api/models/local/download")
async def post_local_model_download(payload: dict = Body(default_factory=dict)):
    model_id = (payload.get("id") or "").strip()
    whisper_model = (payload.get("whisperModel") or "").strip() or None
    if not model_id:
        return {"ok": False, "message": "缺少 id（whisper 或 argos）", **get_local_models_status()}
    try:
        job = await asyncio.to_thread(start_download, model_id, whisper_model=whisper_model)
        return {
            "ok": True,
            "message": job.get("message") or "已开始下载",
            "job": job_public_view(job),
            **get_local_models_status(),
        }
    except Exception as exc:
        log.exception("local model download start failed: %s", model_id)
        return {"ok": False, "message": str(exc), **get_local_models_status()}


@router.get("/api/models/local/download/{job_id}")
def get_local_model_download_job(job_id: str):
    job = get_job(job_id)
    if not job:
        return {"ok": False, "message": "下载任务不存在", **get_local_models_status()}
    payload: dict = {
        "ok": job.get("status") != "error",
        "job": job_public_view(job),
        **get_local_models_status(),
    }
    if job.get("status") == "done":
        payload["message"] = job.get("message") or "下载完成"
        payload.update(get_asr_status())
        payload.update(get_engine_status())
    elif job.get("status") == "error":
        payload["message"] = job.get("error") or job.get("message") or "下载失败"
    else:
        payload["message"] = job.get("message") or "正在下载…"
    active = get_active_download()
    if active:
        payload["activeDownload"] = job_public_view(active)
    return payload


@router.post("/api/models/local/settings")
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


@router.post("/api/models/local/delete")
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
