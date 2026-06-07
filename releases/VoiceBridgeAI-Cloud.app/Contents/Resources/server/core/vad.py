"""RMS-based VAD utterance segmentation with in-utterance refine."""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from core.pcm import PcmBuffer


@dataclass(frozen=True)
class VadParams:
    silence_rms: float = 0.012
    silence_ms: int = 600
    min_utterance_ms: int = 400
    max_utterance_s: float = 30.0
    refine_interval_s: float = 0.8


DEFAULT_VAD = VadParams()


def chunk_rms(pcm: bytes) -> float:
    if len(pcm) < 2:
        return 0.0
    samples = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    return float(np.sqrt(np.mean(samples * samples)))


class ReviseEngine:
    """VAD buffer with periodic refine while the speaker is still talking."""

    def __init__(self, sample_rate: int, vad: VadParams | None = None) -> None:
        self.sample_rate = sample_rate
        self.vad = vad or DEFAULT_VAD
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.next_segment_id = 0
        self.in_utterance = False
        self.current_seg_id = 0
        self.samples_since_refine = 0

    def reset(self, sample_rate: int, vad: VadParams | None = None) -> None:
        self.sample_rate = sample_rate
        if vad is not None:
            self.vad = vad
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.in_utterance = False
        self.samples_since_refine = 0

    def feed(self, chunk: bytes) -> list[tuple[str, int, bytes]]:
        if not chunk:
            return []

        vad = self.vad
        events: list[tuple[str, int, bytes]] = []
        rms = chunk_rms(chunk)
        n_samples = len(chunk) // 2
        self.buffer.append(chunk)

        if rms >= vad.silence_rms:
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
        refine_samples = int(vad.refine_interval_s * self.sample_rate)
        min_utterance_s = vad.min_utterance_ms / 1000
        silence_cutoff_s = vad.silence_ms / 1000

        if self.in_utterance:
            self.samples_since_refine += n_samples
            if self.samples_since_refine >= refine_samples and dur >= min_utterance_s:
                self.samples_since_refine = 0
                pcm = self.buffer.peek()
                if pcm:
                    events.append(("refine", self.current_seg_id, pcm))

        if dur >= vad.max_utterance_s and self.in_utterance:
            events.append(("final", self.current_seg_id, self.buffer.drain()))
            self.in_utterance = False
            self.silence_samples = 0
            self.samples_since_refine = 0
            return events

        if (
            self.in_utterance
            and silence_s >= silence_cutoff_s
            and dur >= min_utterance_s
            and dur > silence_s
        ):
            events.append(("final", self.current_seg_id, self.buffer.drain()))
            self.in_utterance = False
            self.silence_samples = 0
            self.samples_since_refine = 0

        return events

    def flush(self) -> list[tuple[str, int, bytes]]:
        min_utterance_s = self.vad.min_utterance_ms / 1000
        if self.in_utterance and self.buffer.duration(self.sample_rate) >= min_utterance_s:
            self.in_utterance = False
            return [("final", self.current_seg_id, self.buffer.drain())]
        self.buffer = PcmBuffer()
        self.silence_samples = 0
        self.in_utterance = False
        self.samples_since_refine = 0
        return []
