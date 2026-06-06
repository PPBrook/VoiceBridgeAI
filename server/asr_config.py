"""ASR backend selection and status."""

from __future__ import annotations

import os
from typing import Any

from tencent_asr import configured as tencent_configured, engine_model
from whisper_asr import MODEL_NAME as WHISPER_MODEL

ASR_MODES = (
    {"id": "tencent", "label": "云端流式识别 · 低延迟"},
    {"id": "local", "label": "本地离线识别 · 无需密钥"},
)


def set_provider(mode: str | None) -> None:
    if mode in ("tencent", "local"):
        os.environ["ASR_MODE"] = mode
        os.environ["ASR_PROVIDER"] = mode


def default_mode() -> str:
    env = os.getenv("ASR_PROVIDER", "").strip() or os.getenv("ASR_MODE", "").strip()
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
            {"id": "local", "label": "本地离线识别 · 无需密钥"}
        ]
        if current == "tencent":
            current = "local"
    return {
        "asrMode": current,
        "asrProvider": current,
        "asrModes": modes,
        "asrProviders": modes,
        "tencentConfigured": tencent_configured(),
        "whisperModel": WHISPER_MODEL,
        "asrEngine": engine_model() if current == "tencent" else WHISPER_MODEL,
    }
