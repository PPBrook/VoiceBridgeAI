"""RMS-based VAD utterance segmentation."""

from __future__ import annotations

import numpy as np

from pcm import PcmBuffer

SILENCE_RMS = 0.012
SILENCE_MS = 600
MIN_UTTERANCE_MS = 400
MAX_UTTERANCE_S = 30.0


def chunk_rms(pcm: bytes) -> float:
    if len(pcm) < 2:
        return 0.0
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    return float(np.sqrt(np.mean(samples * samples)))


class UtteranceEngine:
    """Accumulate PCM; finalize an utterance after sustained silence."""

    def __init__(self, sample_rate: int) -> None:
        self.sample_rate = sample_rate
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.next_segment_id = 0

    def reset(self, sample_rate: int) -> None:
        self.sample_rate = sample_rate
        self.buffer = PcmBuffer()
        self.silence_samples = 0

    def feed(self, chunk: bytes) -> tuple[int, bytes] | None:
        if not chunk:
            return None

        rms = chunk_rms(chunk)
        n_samples = len(chunk) // 2
        self.buffer.append(chunk)

        if rms < SILENCE_RMS:
            self.silence_samples += n_samples
        else:
            self.silence_samples = 0

        dur = self.buffer.duration(self.sample_rate)
        silence_s = self.silence_samples / self.sample_rate

        if dur >= MAX_UTTERANCE_S:
            return self._finalize()

        if (
            silence_s >= SILENCE_MS / 1000
            and dur >= MIN_UTTERANCE_MS / 1000
            and dur > silence_s
        ):
            return self._finalize()

        return None

    def flush(self) -> tuple[int, bytes] | None:
        if self.buffer.duration(self.sample_rate) >= MIN_UTTERANCE_MS / 1000:
            return self._finalize()
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        return None

    def _finalize(self) -> tuple[int, bytes]:
        pcm = self.buffer.drain()
        self.silence_samples = 0
        seg_id = self.next_segment_id
        self.next_segment_id += 1
        return seg_id, pcm
