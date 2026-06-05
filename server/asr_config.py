"""ASR backend selection and status."""

from __future__ import annotations

import os
from typing import Any

from tencent_asr import configured as tencent_configured, engine_model
from whisper_asr import MODEL_NAME as WHISPER_MODEL

ASR_MODES = (
    {"id": "tencent", "label": "腾讯云实时 ASR（流式，低延迟）"},
    {"id": "local", "label": "本地 Whisper（无需腾讯云）"},
)


def default_mode() -> str:
    env = os.getenv("ASR_MODE", "").strip()
    if env in ("tencent", "local"):
        return env
    return "tencent" if tencent_configured() else "local"


def normalize_mode(mode: str | None) -> str:
    if mode == "tencent":
        if tencent_configured():
            return "tencent"
        return "local"
    if mode == "local":
        return "local"
    return default_mode()


def get_status(mode: str | None = None) -> dict[str, Any]:
    current = normalize_mode(mode)
    modes = list(ASR_MODES)
    if not tencent_configured():
        modes = [m for m in modes if m["id"] != "tencent"] or [
            {"id": "local", "label": "本地 Whisper（无需腾讯云）"}
        ]
        if current == "tencent":
            current = "local"
    return {
        "asrMode": current,
        "asrModes": modes,
        "tencentConfigured": tencent_configured(),
        "whisperModel": WHISPER_MODEL,
        "asrEngine": engine_model() if current == "tencent" else WHISPER_MODEL,
    }
