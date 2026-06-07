"""ASR backend selection and status."""

from __future__ import annotations

import os
from typing import Any

from providers.openai_asr import asr_model as openai_asr_model
from providers.tencent_asr import configured as tencent_configured, engine_model
from providers.whisper_asr import MODEL_NAME as WHISPER_MODEL

from providers.provider_registry import ASR_MODES

_VALID = frozenset(m["id"] for m in ASR_MODES)


def available_modes() -> list[dict[str, str]]:
    from providers.provider_enable import is_verified

    return [dict(m) for m in ASR_MODES if is_verified("asr", m["id"])]


def set_provider(mode: str | None) -> None:
    if mode in _VALID:
        os.environ["ASR_MODE"] = mode
        os.environ["ASR_PROVIDER"] = mode


def default_mode() -> str:
    env = os.getenv("ASR_PROVIDER", "").strip() or os.getenv("ASR_MODE", "").strip()
    available = {m["id"] for m in available_modes()}
    if env in available:
        return env
    modes = available_modes()
    return modes[0]["id"] if modes else ""


def normalize_mode(mode: str | None) -> str:
    if mode in _VALID:
        return mode  # type: ignore[return-value]
    available = {m["id"] for m in available_modes()}
    if mode in available:
        return mode  # type: ignore[return-value]
    if available:
        return default_mode()
    return mode if mode in _VALID else "local"


def get_status(mode: str | None = None) -> dict[str, Any]:
    from providers.openai_asr import configured as openai_configured

    modes = available_modes()
    current = normalize_mode(mode) if mode else default_mode()
    if current and current not in {m["id"] for m in modes}:
        current = modes[0]["id"] if modes else ""

    if current == "tencent":
        engine = engine_model()
    elif current == "openai":
        engine = openai_asr_model()
    else:
        engine = WHISPER_MODEL

    return {
        "asrMode": current,
        "asrProvider": current,
        "asrModes": modes,
        "asrProviders": modes,
        "tencentConfigured": tencent_configured(),
        "openaiAsrConfigured": openai_configured(),
        "whisperModel": WHISPER_MODEL,
        "asrEngine": engine,
    }
