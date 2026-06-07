"""Local model status, settings, and download/uninstall dispatch."""

from __future__ import annotations

from typing import Any

from core.local_models_argos import (
    download_argos,
    is_argos_installed,
    uninstall_argos,
)
from core.local_models_catalog import (
    LOCAL_MODELS,
    WHISPER_CHOICES,
    is_argos_enabled,
    is_whisper_enabled,
    optional_local_models_enabled,
    set_argos_enabled,
    set_whisper_enabled,
    whisper_model_name,
)
from core.local_models_paths import models_root
from core.local_models_whisper import (
    ProgressCallback,
    download_whisper,
    is_whisper_any_installed,
    is_whisper_installed,
    switch_whisper_model,
    uninstall_whisper,
)


def is_installed(model_id: str) -> bool:
    if model_id == "whisper":
        return is_whisper_any_installed()
    if model_id == "argos":
        return is_argos_installed()
    return False


def is_model_enabled(model_id: str) -> bool:
    if model_id == "whisper":
        return is_whisper_enabled()
    if model_id == "argos":
        return is_argos_enabled()
    return False


def is_model_available(model_id: str) -> bool:
    """Installed and user-enabled (shown in engine dropdown)."""
    return is_model_enabled(model_id) and is_installed(model_id)


def apply_local_model_settings(payload: dict[str, Any]) -> None:
    from config.env_persist import persist_local_model_settings

    persist_payload: dict[str, Any] = {}
    if "whisperEnabled" in payload:
        enabled = bool(payload["whisperEnabled"])
        set_whisper_enabled(enabled)
        persist_payload["whisperEnabled"] = enabled
    if "argosEnabled" in payload:
        enabled = bool(payload["argosEnabled"])
        set_argos_enabled(enabled)
        persist_payload["argosEnabled"] = enabled

    action = (payload.get("action") or "").strip().lower()
    whisper_model = (payload.get("whisperModel") or "").strip()
    if action == "switch" and whisper_model:
        switch_whisper_model(whisper_model)
    if persist_payload:
        persist_local_model_settings(persist_payload)


def download(
    model_id: str,
    *,
    whisper_model: str | None = None,
    on_progress: ProgressCallback | None = None,
) -> str:
    if model_id == "whisper":
        return download_whisper(whisper_model, on_progress=on_progress)
    if model_id == "argos":
        download_argos(on_progress=on_progress)
        return "argos"
    raise ValueError(f"unknown local model: {model_id}")


def uninstall(model_id: str, *, whisper_model: str | None = None) -> str:
    if model_id == "whisper":
        return uninstall_whisper(whisper_model)
    if model_id == "argos":
        uninstall_argos()
        return "argos"
    raise ValueError(f"unknown local model: {model_id}")


def get_status() -> dict[str, Any]:
    whisper = whisper_model_name()
    models: list[dict[str, Any]] = []
    for item in LOCAL_MODELS:
        entry: dict[str, Any] = {
            **item,
            "installed": is_installed(item["id"]),
            "enabled": is_model_enabled(item["id"]),
            "available": is_model_available(item["id"]),
        }
        if item["id"] == "whisper":
            entry["installedModels"] = [
                m["id"] for m in WHISPER_CHOICES if is_whisper_installed(m["id"])
            ]
            entry["activeModel"] = whisper
            entry["activeInstalled"] = is_whisper_installed(whisper)
        models.append(entry)
    return {
        "optionalLocalModels": optional_local_models_enabled(),
        "modelsDir": str(models_root()),
        "whisperModel": whisper,
        "whisperChoices": list(WHISPER_CHOICES),
        "whisperEnabled": is_whisper_enabled(),
        "argosEnabled": is_argos_enabled(),
        "localModels": models,
    }
