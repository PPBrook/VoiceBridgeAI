"""Debounced translation, in-place revise, and lookback correction."""

from __future__ import annotations

import asyncio
import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from typing import Any, Optional

from revise_config import ReviseParams, get_params as get_revise_params

SendFn = Callable[[dict[str, Any]], Awaitable[bool]]
TranslatePartialFn = Callable[[str], str]
TranslateFinalFn = Callable[[str, Optional[str]], str]


def _norm(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def _meaningful_change(before: str, after: str) -> bool:
    if before == after:
        return False
    if _norm(before) == _norm(after):
        return False
    if not before or not after:
        return True
    shorter = min(len(before), len(after))
    longer = max(len(before), len(after))
    if longer and shorter / longer < 0.55:
        return True
    return before != after


def _partial_translate_delay(text: str, has_zh: bool, params: ReviseParams) -> float:
    if has_zh:
        return params.debounce_s
    stripped = text.strip()
    if len(stripped) < params.min_chars:
        return 0.12
    return 0.0


@dataclass
class SegmentState:
    en: str = ""
    zh: str = ""
    final: bool = False
    pcm: bytes | None = None
    sample_rate: int = 16000


class ReviseScheduler:
    """Partial drafts via MT; final polish via LLM; lookback fixes prior segments."""

    def __init__(
        self,
        translate_partial: TranslatePartialFn,
        translate_final: TranslateFinalFn,
        send: SendFn,
        params: ReviseParams | None = None,
    ) -> None:
        self._translate_partial = translate_partial
        self._translate_final = translate_final
        self._send = send
        self._params = params or get_revise_params()
        self._draft_en: dict[int, str] = {}
        self._draft_zh: dict[int, str] = {}
        self._tasks: dict[int, asyncio.Task] = {}
        self._latest_en: dict[int, str] = {}
        self._committed: dict[int, SegmentState] = {}

    def _cancel(self, seg_id: int) -> None:
        task = self._tasks.pop(seg_id, None)
        if task and not task.done():
            task.cancel()

    def _state(self, seg_id: int) -> SegmentState:
        if seg_id not in self._committed:
            self._committed[seg_id] = SegmentState()
        return self._committed[seg_id]

    def attach_pcm(self, seg_id: int, pcm: bytes, sample_rate: int) -> None:
        st = self._state(seg_id)
        st.pcm = pcm
        st.sample_rate = sample_rate

    async def emit_english(
        self,
        seg_id: int,
        text: str,
        *,
        partial: bool,
        final: bool,
    ) -> None:
        st = self._state(seg_id)
        prev_en = st.en if st.final else self._draft_en.get(seg_id, "")
        en_revise = bool(prev_en) and _meaningful_change(prev_en, text)

        if st.final and _meaningful_change(st.en, text):
            st.final = False
            self._draft_en[seg_id] = text
            self._draft_zh.pop(seg_id, None)
        elif not st.final:
            self._draft_en[seg_id] = text

        self._latest_en[seg_id] = text
        if en_revise and not st.final:
            self._draft_zh.pop(seg_id, None)

        zh = "" if en_revise else (st.zh if st.final else self._draft_zh.get(seg_id, ""))
        await self._send(
            {
                "type": "asr",
                "segmentId": seg_id,
                "text": text,
                "translation": zh,
                "partial": partial,
                "final": final and st.final,
                "revise": en_revise,
            }
        )

    async def schedule_partial_translation(self, seg_id: int, text: str) -> None:
        st = self._state(seg_id)
        if st.final:
            return
        self._latest_en[seg_id] = text
        if self._draft_zh.get(seg_id) and self._draft_en.get(seg_id) == text:
            return
        delay = _partial_translate_delay(
            text, seg_id in self._draft_zh, self._params
        )
        self._cancel(seg_id)
        self._tasks[seg_id] = asyncio.create_task(
            self._debounced_translate(seg_id, text, delay)
        )

    async def finalize(self, seg_id: int, text: str) -> None:
        self._cancel(seg_id)
        self._latest_en[seg_id] = text
        st = self._state(seg_id)
        en_revise = bool(st.en) and _meaningful_change(st.en, text)
        had_zh = bool(st.zh or self._draft_zh.get(seg_id))
        prev_zh = (st.zh or self._draft_zh.get(seg_id, "")) or None

        st.en = text
        st.final = True
        self._draft_en.pop(seg_id, None)

        zh = await asyncio.to_thread(self._translate_final, text, prev_zh)
        zh_revise = had_zh and prev_zh and _meaningful_change(prev_zh, zh)
        st.zh = zh
        self._draft_zh.pop(seg_id, None)
        self._latest_en.pop(seg_id, None)

        await self._send(
            {
                "type": "asr",
                "segmentId": seg_id,
                "text": text,
                "translation": zh,
                "partial": False,
                "final": True,
                "revise": en_revise or zh_revise or had_zh,
            }
        )

    async def correct_segment(
        self,
        seg_id: int,
        text: str,
        *,
        retranslate: bool = True,
    ) -> bool:
        """Update a committed segment when lookback ASR finds a fix."""
        st = self._state(seg_id)
        if not _meaningful_change(st.en, text):
            return False

        prev_zh = st.zh or None
        en_revise = bool(st.en)
        st.en = text
        st.final = True

        if not retranslate:
            await self._send(
                {
                    "type": "asr",
                    "segmentId": seg_id,
                    "text": text,
                    "translation": st.zh,
                    "partial": False,
                    "final": True,
                    "revise": en_revise,
                }
            )
            return True

        zh = await asyncio.to_thread(self._translate_final, text, prev_zh)
        zh_revise = bool(prev_zh) and _meaningful_change(prev_zh, zh)
        st.zh = zh
        await self._send(
            {
                "type": "asr",
                "segmentId": seg_id,
                "text": text,
                "translation": zh,
                "partial": False,
                "final": True,
                "revise": True,
                "lookback": True,
            }
        )
        return en_revise or zh_revise

    async def lookback_boundary(self, prev_id: int, curr_id: int) -> None:
        """Re-transcribe the join of two utterances and fix boundary errors."""
        prev = self._committed.get(prev_id)
        curr = self._committed.get(curr_id)
        if not prev or not curr or not prev.pcm or not curr.pcm:
            return

        from whisper_asr import transcribe_split

        combined = prev.pcm + curr.pcm
        split_at_sec = len(prev.pcm) / 2 / max(prev.sample_rate, 1)

        try:
            before, after = await asyncio.to_thread(
                transcribe_split, combined, prev.sample_rate, split_at_sec
            )
        except Exception:
            return

        if before and _meaningful_change(prev.en, before):
            await self.correct_segment(prev_id, before)
        if after and _meaningful_change(curr.en, after):
            await self.correct_segment(curr_id, after)

    async def run_lookback(self, anchor_id: int) -> None:
        """After anchor_id finalizes, re-check recent utterance boundaries."""
        lookback = self._params.lookback
        if lookback <= 0:
            return
        start = max(0, anchor_id - lookback + 1)
        for i in range(start, anchor_id):
            await self.lookback_boundary(i, i + 1)

    async def _debounced_translate(
        self, seg_id: int, text: str, delay: float
    ) -> None:
        try:
            if delay > 0:
                await asyncio.sleep(delay)
            if self._latest_en.get(seg_id) != text:
                return
            st = self._state(seg_id)
            if st.final:
                return
            zh = await asyncio.to_thread(self._translate_partial, text)
            if self._latest_en.get(seg_id) != text:
                return
            zh_revise = seg_id in self._draft_zh or bool(st.zh)
            self._draft_zh[seg_id] = zh
            await self._send(
                {
                    "type": "asr",
                    "segmentId": seg_id,
                    "text": text,
                    "translation": zh,
                    "partial": True,
                    "final": False,
                    "revise": zh_revise,
                }
            )
        except asyncio.CancelledError:
            raise

    def clear(self) -> None:
        for seg_id in list(self._tasks):
            self._cancel(seg_id)
        self._latest_en.clear()
        self._draft_en.clear()
        self._draft_zh.clear()
        self._committed.clear()
