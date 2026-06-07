"""Background local model downloads with progress reporting."""

from __future__ import annotations

import threading
import uuid
from typing import Any, Callable

from core import local_models
from core.local_model_messages import done_text, error_text, model_label, progress_text

ProgressCallback = Callable[[float, str], None]

_lock = threading.Lock()
_jobs: dict[str, dict[str, Any]] = {}
_active_by_key: dict[str, str] = {}


def _job_key(model_id: str, whisper_model: str | None) -> str:
    if model_id == "whisper":
        wm = (whisper_model or local_models.whisper_model_name()).strip()
        return f"whisper:{wm}"
    return model_id


def _snapshot(job_id: str) -> dict[str, Any] | None:
    job = _jobs.get(job_id)
    return dict(job) if job else None


def get_job(job_id: str) -> dict[str, Any] | None:
    with _lock:
        return _snapshot(job_id)


def get_active_download() -> dict[str, Any] | None:
    with _lock:
        for job_id in _active_by_key.values():
            job = _snapshot(job_id)
            if job and job.get("status") == "running":
                return job
        return None


def _validate_download(model_id: str, whisper_model: str | None) -> str:
    label = model_label(model_id, whisper_model)
    if model_id == "whisper":
        name = (whisper_model or local_models.whisper_model_name()).strip()
        if name not in {item["id"] for item in local_models.WHISPER_CHOICES}:
            raise ValueError(f"unknown whisper model: {name}")
        if local_models.is_whisper_installed(name):
            raise RuntimeError(f"{label} 已安装")
    elif model_id == "argos":
        if local_models.is_argos_installed():
            raise RuntimeError(f"{label} 已安装")
    else:
        raise ValueError(f"unknown local model: {model_id}")
    return label


def start_download(model_id: str, *, whisper_model: str | None = None) -> dict[str, Any]:
    label = _validate_download(model_id, whisper_model)
    key = _job_key(model_id, whisper_model)
    with _lock:
        existing_id = _active_by_key.get(key)
        if existing_id:
            existing = _snapshot(existing_id)
            if existing and existing.get("status") == "running":
                existing["message"] = progress_text(
                    label,
                    "正在下载",
                    ratio=existing.get("progress", 0.0),
                )
                _jobs[existing_id] = existing
                return existing

        job_id = uuid.uuid4().hex[:12]
        job = {
            "id": job_id,
            "modelId": model_id,
            "whisperModel": whisper_model,
            "label": label,
            "status": "running",
            "progress": 0.0,
            "message": progress_text(label, "准备下载"),
            "error": None,
        }
        _jobs[job_id] = job
        _active_by_key[key] = job_id

    thread = threading.Thread(
        target=_run_download,
        args=(job_id, model_id, whisper_model, label),
        daemon=True,
        name=f"local-model-download-{job_id}",
    )
    thread.start()
    return dict(job)


def _set_job(job_id: str, **fields: Any) -> None:
    with _lock:
        if job_id in _jobs:
            _jobs[job_id].update(fields)


def _clear_active(job_id: str, model_id: str, whisper_model: str | None) -> None:
    key = _job_key(model_id, whisper_model)
    with _lock:
        if _active_by_key.get(key) == job_id:
            del _active_by_key[key]


def _run_download(job_id: str, model_id: str, whisper_model: str | None, label: str) -> None:
    def report(progress: float, message: str) -> None:
        _set_job(
            job_id,
            progress=max(0.0, min(1.0, progress)),
            message=message,
        )

    try:
        local_models.download(model_id, whisper_model=whisper_model, on_progress=report)
        if model_id == "whisper" and whisper_model:
            import os

            os.environ["WHISPER_MODEL"] = whisper_model
            from config.env_persist import persist_local_model_settings

            persist_local_model_settings({"whisperModel": whisper_model})
            from providers.whisper_asr import unload_model

            unload_model()
        _set_job(job_id, status="done", progress=1.0, message=done_text(label), error=None)
    except Exception as exc:
        detail = str(exc)
        _set_job(
            job_id,
            status="error",
            message=error_text(label, detail),
            error=detail,
        )
    finally:
        _clear_active(job_id, model_id, whisper_model)


def job_public_view(job: dict[str, Any] | None) -> dict[str, Any] | None:
    if not job:
        return None
    return {
        "id": job.get("id"),
        "modelId": job.get("modelId"),
        "whisperModel": job.get("whisperModel"),
        "label": job.get("label"),
        "status": job.get("status"),
        "progress": job.get("progress", 0.0),
        "message": job.get("message", ""),
        "error": job.get("error"),
    }
