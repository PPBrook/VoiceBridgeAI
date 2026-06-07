"""Optional on-demand local models (Whisper, Argos) — facade for backward-compatible imports."""

from __future__ import annotations

from core.local_models_api import (
    ProgressCallback,
    apply_local_model_settings,
    download,
    get_status,
    is_installed,
    is_model_available,
    is_model_enabled,
    uninstall,
)
from core.local_models_argos import download_argos, is_argos_installed, uninstall_argos
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
from core.local_models_paths import configure_model_cache_env, models_root
from core.local_models_whisper import (
    download_whisper,
    is_whisper_any_installed,
    is_whisper_installed,
    mark_whisper_installed,
    switch_whisper_model,
    uninstall_whisper,
)

__all__ = [
    "LOCAL_MODELS",
    "WHISPER_CHOICES",
    "ProgressCallback",
    "apply_local_model_settings",
    "configure_model_cache_env",
    "download",
    "download_argos",
    "download_whisper",
    "get_status",
    "is_argos_enabled",
    "is_argos_installed",
    "is_installed",
    "is_model_available",
    "is_model_enabled",
    "is_whisper_any_installed",
    "is_whisper_enabled",
    "is_whisper_installed",
    "mark_whisper_installed",
    "models_root",
    "optional_local_models_enabled",
    "set_argos_enabled",
    "set_whisper_enabled",
    "switch_whisper_model",
    "uninstall",
    "uninstall_argos",
    "uninstall_whisper",
    "whisper_model_name",
]
