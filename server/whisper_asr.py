"""Local Whisper ASR (offline fallback)."""

from __future__ import annotations

import logging
from typing import Optional

import numpy as np
from faster_whisper import WhisperModel

from pcm import TARGET_RATE

log = logging.getLogger(__name__)

MODEL_NAME = "tiny.en"
_model: Optional[WhisperModel] = None


def load_model() -> None:
    global _model
    if _model is not None:
        return
    log.info("Loading Whisper %s (cpu, int8) …", MODEL_NAME)
    _model = WhisperModel(MODEL_NAME, device="cpu", compute_type="int8")
    log.info("Whisper ready")


def transcribe(pcm: bytes, sample_rate: int) -> str:
    if _model is None:
        load_model()
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    if sample_rate != TARGET_RATE and sample_rate:
        n = int(len(audio) * TARGET_RATE / sample_rate)
        if n < 1:
            return ""
        idx = np.linspace(0, len(audio) - 1, n)
        audio = np.interp(idx, np.arange(len(audio)), audio).astype(np.float32)
    if len(audio) < TARGET_RATE * 0.35:
        return ""
    segments, _ = _model.transcribe(
        audio,
        language="en",
        vad_filter=True,
        beam_size=1,
    )
    return " ".join(s.text.strip() for s in segments if s.text.strip())
