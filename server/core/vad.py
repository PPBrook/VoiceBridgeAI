"""RMS-based VAD utterance segmentation with in-utterance refine."""

from __future__ import annotations

import os

import numpy as np

from core.pcm import PcmBuffer

SILENCE_RMS = 0.012
SILENCE_MS = 600
MIN_UTTERANCE_MS = 400
MAX_UTTERANCE_S = 30.0
REFINE_INTERVAL_S = float(os.getenv("REFINE_INTERVAL", "0.8"))


def chunk_rms(pcm: bytes) -> float:
    if len(pcm) < 2:
        return 0.0
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    return float(np.sqrt(np.mean(samples * samples)))


class ReviseEngine:
    """VAD buffer with periodic refine while the speaker is still talking."""

    def __init__(self, sample_rate: int, refine_interval_s: float | None = None) -> None:
        self.sample_rate = sample_rate
        self.refine_interval_s = (
            refine_interval_s if refine_interval_s is not None else REFINE_INTERVAL_S
        )
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.next_segment_id = 0
        self.in_utterance = False
        self.current_seg_id = 0
        self.samples_since_refine = 0

    def reset(self, sample_rate: int, refine_interval_s: float | None = None) -> None:
        self.sample_rate = sample_rate
        if refine_interval_s is not None:
            self.refine_interval_s = refine_interval_s
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.in_utterance = False
        self.samples_since_refine = 0

    def feed(self, chunk: bytes) -> list[tuple[str, int, bytes]]:
        if not chunk:
            return []

        events: list[tuple[str, int, bytes]] = []
        rms = chunk_rms(chunk)
        n_samples = len(chunk) // 2
        self.buffer.append(chunk)

        if rms >= SILENCE_RMS:
            if not self.in_utterance:
                self.in_utterance = True
                self.current_seg_id = self.next_segment_id
                self.next_segment_id += 1
                self.samples_since_refine = 0
            self.silence_samples = 0
        else:
            self.silence_samples += n_samples

        dur = self.buffer.duration(self.sample_rate)
        silence_s = self.silence_samples / self.sample_rate
        refine_samples = int(self.refine_interval_s * self.sample_rate)

        if self.in_utterance:
            self.samples_since_refine += n_samples
            if (
                self.samples_since_refine >= refine_samples
                and dur >= MIN_UTTERANCE_MS / 1000
            ):
                self.samples_since_refine = 0
                pcm = self.buffer.peek()
                if pcm:
                    events.append(("refine", self.current_seg_id, pcm))

        if dur >= MAX_UTTERANCE_S and self.in_utterance:
            events.append(("final", self.current_seg_id, self.buffer.drain()))
            self.in_utterance = False
            self.silence_samples = 0
            self.samples_since_refine = 0
            return events

        if (
            self.in_utterance
            and silence_s >= SILENCE_MS / 1000
            and dur >= MIN_UTTERANCE_MS / 1000
            and dur > silence_s
        ):
            events.append(("final", self.current_seg_id, self.buffer.drain()))
            self.in_utterance = False
            self.silence_samples = 0
            self.samples_since_refine = 0

        return events

    def flush(self) -> list[tuple[str, int, bytes]]:
        if (
            self.in_utterance
            and self.buffer.duration(self.sample_rate) >= MIN_UTTERANCE_MS / 1000
        ):
            self.in_utterance = False
            return [("final", self.current_seg_id, self.buffer.drain())]
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.in_utterance = False
        self.samples_since_refine = 0
        return []
