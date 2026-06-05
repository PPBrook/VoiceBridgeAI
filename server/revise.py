"""Debounced translation and revise signalling for in-place subtitle updates."""

from __future__ import annotations

import asyncio
import os
from collections.abc import Awaitable, Callable
from typing import Any, Optional

SendFn = Callable[[dict[str, Any]], Awaitable[bool]]
TranslatePartialFn = Callable[[str], str]
TranslateFinalFn = Callable[[str, Optional[str]], str]

TRANSLATE_DEBOUNCE_S = float(os.getenv("TRANSLATE_DEBOUNCE", "0.25"))
TRANSLATE_MIN_CHARS = int(os.getenv("TRANSLATE_MIN_CHARS", "3"))


def _partial_translate_delay(seg_id: int, text: str, has_zh: bool) -> float:
    if has_zh:
        return TRANSLATE_DEBOUNCE_S
    stripped = text.strip()
    if len(stripped) < TRANSLATE_MIN_CHARS:
        return 0.12
    return 0.0


class ReviseScheduler:
    """Partial drafts via MT; final polish via LLM."""

    def __init__(
        self,
        translate_partial: TranslatePartialFn,
        translate_final: TranslateFinalFn,
        send: SendFn,
    ) -> None:
        self._translate_partial = translate_partial
        self._translate_final = translate_final
        self._send = send
        self._latest_en: dict[int, str] = {}
        self._last_en: dict[int, str] = {}
        self._last_zh: dict[int, str] = {}
        self._tasks: dict[int, asyncio.Task] = {}

    def _cancel(self, seg_id: int) -> None:
        task = self._tasks.pop(seg_id, None)
        if task and not task.done():
            task.cancel()

    async def emit_english(
        self,
        seg_id: int,
        text: str,
        *,
        partial: bool,
        final: bool,
    ) -> None:
        revise = seg_id in self._last_en and self._last_en[seg_id] != text
        self._last_en[seg_id] = text
        self._latest_en[seg_id] = text
        if revise:
            self._last_zh.pop(seg_id, None)
        await self._send(
            {
                "type": "asr",
                "segmentId": seg_id,
                "text": text,
                "translation": "" if revise else self._last_zh.get(seg_id, ""),
                "partial": partial,
                "final": final,
                "revise": revise,
            }
        )

    async def schedule_partial_translation(self, seg_id: int, text: str) -> None:
        self._latest_en[seg_id] = text
        if self._last_zh.get(seg_id) and self._last_en.get(seg_id) == text:
            return
        delay = _partial_translate_delay(seg_id, text, seg_id in self._last_zh)
        self._cancel(seg_id)
        self._tasks[seg_id] = asyncio.create_task(
            self._debounced_translate(seg_id, text, delay)
        )

    async def finalize(self, seg_id: int, text: str) -> None:
        self._cancel(seg_id)
        self._latest_en[seg_id] = text
        en_revise = seg_id in self._last_en and self._last_en[seg_id] != text
        had_zh = seg_id in self._last_zh
        prev_zh = self._last_zh.get(seg_id, "") or None
        self._last_en[seg_id] = text

        zh = await asyncio.to_thread(self._translate_final, text, prev_zh)
        zh_revise = had_zh and prev_zh and prev_zh != zh
        self._last_zh[seg_id] = zh

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
        self._last_en.pop(seg_id, None)
        self._last_zh.pop(seg_id, None)
        self._latest_en.pop(seg_id, None)

    async def _debounced_translate(
        self, seg_id: int, text: str, delay: float
    ) -> None:
        try:
            if delay > 0:
                await asyncio.sleep(delay)
            if self._latest_en.get(seg_id) != text:
                return
            zh = await asyncio.to_thread(self._translate_partial, text)
            if self._latest_en.get(seg_id) != text:
                return
            zh_revise = seg_id in self._last_zh
            self._last_zh[seg_id] = zh
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
        self._last_en.clear()
        self._last_zh.clear()
