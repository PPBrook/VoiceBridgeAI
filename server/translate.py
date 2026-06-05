"""Dual-engine translation: partial=TMT, final=Qiniu LLM (with fallbacks)."""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any, Optional

from translate_qiniu import configured as qiniu_configured
from translate_qiniu import model_name as qiniu_model
from translate_qiniu import translate as qiniu_translate
from translate_tmt import configured as tmt_configured
from translate_tmt import region as tmt_region
from translate_tmt import translate as tmt_translate

log = logging.getLogger(__name__)


def _google_translate(text: str) -> str:
    from deep_translator import GoogleTranslator

    return GoogleTranslator(source="en", target="zh-CN").translate(text.strip())


@lru_cache(maxsize=512)
def _cached_partial(text: str) -> str:
    return _translate_partial_uncached(text)


@lru_cache(maxsize=256)
def _cached_final(text: str, draft: str) -> str:
    return _translate_final_uncached(text, draft or None)


def _translate_partial_uncached(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    if tmt_configured():
        try:
            return tmt_translate(text)
        except Exception as exc:
            log.warning("TMT partial failed, fallback: %s", exc)
    try:
        return _google_translate(text)
    except Exception as exc:
        log.exception("partial translate failed")
        raise RuntimeError(f"partial translate failed: {exc}") from exc


def _translate_final_uncached(text: str, draft_zh: Optional[str]) -> str:
    text = text.strip()
    if not text:
        return ""
    if qiniu_configured():
        try:
            return qiniu_translate(text, draft_zh)
        except Exception as exc:
            log.warning("Qiniu final failed, fallback: %s", exc)
    if tmt_configured():
        try:
            return tmt_translate(text)
        except Exception as exc:
            log.warning("TMT final fallback failed: %s", exc)
    try:
        return _google_translate(text)
    except Exception as exc:
        log.exception("final translate failed")
        raise RuntimeError(f"final translate failed: {exc}") from exc


def translate_partial(text: str) -> str:
    """Fast draft translation while the speaker is still talking."""
    return _cached_partial(text.strip())


def translate_final(text: str, draft_zh: Optional[str] = None) -> str:
    """Polished translation when the utterance is finalized."""
    key = (text.strip(), (draft_zh or "").strip())
    return _cached_final(key[0], key[1])


def get_status() -> dict[str, Any]:
    partial = "tencent-tmt" if tmt_configured() else "google"
    if qiniu_configured():
        final = "qiniu-llm"
    elif tmt_configured():
        final = "tencent-tmt"
    else:
        final = "google"
    return {
        "translatePartial": partial,
        "translateFinal": final,
        "tmtConfigured": tmt_configured(),
        "qiniuConfigured": qiniu_configured(),
        "qiniuModel": qiniu_model() if qiniu_configured() else None,
        "tmtRegion": tmt_region() if tmt_configured() else None,
    }


# Backward-compatible alias
def translate(text: str) -> str:
    return translate_partial(text)
