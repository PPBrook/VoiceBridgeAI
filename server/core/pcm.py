"""PCM resampling and buffering."""

from __future__ import annotations

import numpy as np

TARGET_RATE = 16000
FRAME_BYTES = 6400  # 200ms @ 16kHz mono int16


def resample_to_16k(pcm: bytes, sample_rate: int) -> bytes:
    audio = np.frombuffer(pcm, dtype=np.int16)
    if len(audio) == 0:
        return b""
    if sample_rate == TARGET_RATE or not sample_rate:
        return pcm
    n = int(len(audio) * TARGET_RATE / sample_rate)
    if n < 1:
        return b""
    idx = np.linspace(0, len(audio) - 1, n)
    out = np.interp(idx, np.arange(len(audio)), audio.astype(np.float32))
    return out.astype(np.int16).tobytes()


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

    def peek(self) -> bytes:
        if not self._parts:
            return b""
        return b"".join(self._parts)


class PcmFramer:
    """Accumulate 16k PCM and emit 200ms frames for Tencent ASR."""

    def __init__(self, frame_bytes: int = FRAME_BYTES) -> None:
        self.frame_bytes = frame_bytes
        self._buf = bytearray()

    def push(self, pcm: bytes) -> list[bytes]:
        if not pcm:
            return []
        self._buf.extend(pcm)
        frames: list[bytes] = []
        while len(self._buf) >= self.frame_bytes:
            frames.append(bytes(self._buf[: self.frame_bytes]))
            del self._buf[: self.frame_bytes]
        return frames

    def flush(self) -> bytes:
        if not self._buf:
            return b""
        data = bytes(self._buf)
        self._buf.clear()
        return data
