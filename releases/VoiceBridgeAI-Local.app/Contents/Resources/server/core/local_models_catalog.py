"""Local model catalog and enable flags."""

from __future__ import annotations

import os

LOCAL_MODELS = (
    {
        "id": "whisper",
        "label": "Whisper 语音识别",
        "description": "本地离线 ASR（faster-whisper，CPU int8）",
        "sizeHint": "~75 MB（tiny.en）",
        "layer": "asr",
    },
    {
        "id": "argos",
        "label": "Argos 英译中",
        "description": "离线句中/句末翻译语言包（en→zh）",
        "sizeHint": "~100 MB",
        "layer": "partial",
    },
)

WHISPER_CHOICES = (
    {"id": "tiny.en", "label": "tiny.en · 推荐（体积小）", "sizeHint": "~75 MB"},
    {"id": "base.en", "label": "base.en · 更准确", "sizeHint": "~150 MB"},
)


def optional_local_models_enabled() -> bool:
    raw = os.getenv("VOICEBRIDGE_OPTIONAL_LOCAL_MODELS", "1").strip().lower()
    return raw not in ("0", "false", "no", "off")


def _env_flag(name: str, *, default: bool = True) -> bool:
    raw = os.getenv(name, "1" if default else "0").strip().lower()
    return raw not in ("0", "false", "no", "off")


def is_whisper_enabled() -> bool:
    return _env_flag("LOCAL_WHISPER_ENABLED", default=True)


def is_argos_enabled() -> bool:
    return _env_flag("LOCAL_ARGOS_ENABLED", default=True)


def set_whisper_enabled(enabled: bool) -> None:
    os.environ["LOCAL_WHISPER_ENABLED"] = "1" if enabled else "0"
    if not enabled:
        try:
            from providers.whisper_asr import unload_model

            unload_model()
        except Exception:
            pass


def set_argos_enabled(enabled: bool) -> None:
    os.environ["LOCAL_ARGOS_ENABLED"] = "1" if enabled else "0"


def whisper_model_name() -> str:
    return os.getenv("WHISPER_MODEL", "tiny.en").strip() or "tiny.en"
