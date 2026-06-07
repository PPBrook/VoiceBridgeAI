"""Local Whisper ASR (offline fallback)."""

from __future__ import annotations

import logging
import os
from typing import Optional

import numpy as np
from faster_whisper import WhisperModel

from core.pcm import TARGET_RATE

log = logging.getLogger(__name__)

MODEL_NAME = os.getenv("WHISPER_MODEL", "tiny.en").strip() or "tiny.en"
_model: Optional[WhisperModel] = None


def load_model() -> None:
    global _model
    if _model is not None:
        return
    from core.local_models import (
        configure_model_cache_env,
        is_whisper_installed,
        mark_whisper_installed,
        optional_local_models_enabled,
    )

    configure_model_cache_env()
    if optional_local_models_enabled() and not is_whisper_installed(MODEL_NAME):
        raise RuntimeError(
            f"Whisper 模型 {MODEL_NAME} 未安装。请在设置中下载本地模型，或改用云端 ASR。"
        )
    log.info("Loading Whisper %s (cpu, int8) …", MODEL_NAME)
    _model = WhisperModel(MODEL_NAME, device="cpu", compute_type="int8")
    mark_whisper_installed(MODEL_NAME)
    log.info("Whisper ready")


def _prepare_audio(pcm: bytes, sample_rate: int) -> np.ndarray:
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    if sample_rate != TARGET_RATE and sample_rate:
        n = int(len(audio) * TARGET_RATE / sample_rate)
        if n < 1:
            return np.array([], dtype=np.float32)
        idx = np.linspace(0, len(audio) - 1, n)
        audio = np.interp(idx, np.arange(len(audio)), audio).astype(np.float32)
    return audio


def transcribe(pcm: bytes, sample_rate: int) -> str:
    if _model is None:
        load_model()
    audio = _prepare_audio(pcm, sample_rate)
    if len(audio) < TARGET_RATE * 0.35:
        return ""
    segments, _ = _model.transcribe(
        audio,
        language="en",
        vad_filter=True,
        beam_size=1,
    )
    return " ".join(s.text.strip() for s in segments if s.text.strip())


def transcribe_split(
    pcm: bytes, sample_rate: int, split_at_sec: float
) -> tuple[str, str]:
    """Return (before, after) text at a time boundary in the recording."""
    if _model is None:
        load_model()
    audio = _prepare_audio(pcm, sample_rate)
    if len(audio) < TARGET_RATE * 0.35:
        return "", ""
    segments, _ = _model.transcribe(
        audio,
        language="en",
        vad_filter=True,
        beam_size=1,
    )
    before: list[str] = []
    after: list[str] = []
    for seg in segments:
        text = seg.text.strip()
        if not text:
            continue
        if seg.end <= split_at_sec + 0.08:
            before.append(text)
        elif seg.start >= split_at_sec - 0.08:
            after.append(text)
        else:
            mid = (seg.start + seg.end) / 2
            (before if mid < split_at_sec else after).append(text)
    return " ".join(before), " ".join(after)
