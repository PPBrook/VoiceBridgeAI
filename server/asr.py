"""Whisper ASR helpers."""

from __future__ import annotations

import logging
from typing import Optional

import numpy as np
from faster_whisper import WhisperModel

log = logging.getLogger(__name__)

TARGET_RATE = 16000
_model: Optional[WhisperModel] = None


def load_model() -> None:
    global _model
    if _model is not None:
        return
    log.info("Loading Whisper base.en (cpu, int8) …")
    _model = WhisperModel("base.en", device="cpu", compute_type="int8")
    log.info("Whisper ready")


def resample(pcm: bytes, sample_rate: int) -> np.ndarray:
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    if sample_rate == TARGET_RATE or not sample_rate:
        return audio
    n = int(len(audio) * TARGET_RATE / sample_rate)
    if n < 1:
        return np.array([], dtype=np.float32)
    idx = np.linspace(0, len(audio) - 1, n)
    return np.interp(idx, np.arange(len(audio)), audio).astype(np.float32)


def transcribe(pcm: bytes, sample_rate: int) -> str:
    if _model is None:
        load_model()
    audio = resample(pcm, sample_rate)
    if len(audio) < TARGET_RATE * 0.5:
        return ""
    segments, _ = _model.transcribe(
        audio,
        language="en",
        vad_filter=True,
        beam_size=1,
    )
    return " ".join(s.text.strip() for s in segments if s.text.strip())


class PcmBuffer:
    def __init__(self) -> None:
        self._parts: list[bytes] = []
        self._bytes = 0

    def append(self, chunk: bytes) -> None:
        self._parts.append(chunk)
        self._bytes += len(chunk)

    @property
    def byte_count(self) -> int:
        return self._bytes

    def duration(self, sample_rate: int) -> float:
        if not sample_rate:
            return 0.0
        return (self._bytes / 2) / sample_rate

    def drain(self) -> bytes:
        if not self._parts:
            return b""
        data = b"".join(self._parts)
        self._parts.clear()
        self._bytes = 0
        return data
