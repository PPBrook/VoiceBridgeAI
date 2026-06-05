"""Translation routing by selected mode."""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any, Optional

from translate_argos import translate as argos_translate
from translate_config import default_mode, get_status, normalize_mode
from translate_opus import translate as opus_translate
from translate_qiniu import translate as qiniu_translate
from translate_tmt import translate as tmt_translate

log = logging.getLogger(__name__)


def _google_translate(text: str) -> str:
    from deep_translator import GoogleTranslator

    return GoogleTranslator(source="en", target="zh-CN").translate(text.strip())


def _offline_translate(mode: str, text: str) -> str:
    if mode == "argos":
        return argos_translate(text)
    if mode == "opus":
        return opus_translate(text)
    raise ValueError(f"unknown offline mode: {mode}")


@lru_cache(maxsize=512)
def _cached_partial(mode: str, text: str) -> str:
    return _translate_partial_uncached(mode, text)


@lru_cache(maxsize=256)
def _cached_final(mode: str, text: str, draft: str) -> str:
    return _translate_final_uncached(mode, text, draft or None)


def _translate_partial_uncached(mode: str, text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    mode = normalize_mode(mode)
    if mode in ("dual", "tencent"):
        try:
            return tmt_translate(text)
        except Exception as exc:
            log.warning("TMT partial failed (%s), fallback: %s", mode, exc)
    if mode == "qiniu":
        try:
            return qiniu_translate(text, None)
        except Exception as exc:
            log.warning("Qiniu partial failed, fallback: %s", exc)
    if mode in ("argos", "opus"):
        try:
            return _offline_translate(mode, text)
        except Exception as exc:
            log.exception("offline partial failed (%s)", mode)
            raise RuntimeError(f"offline translate failed: {exc}") from exc
    try:
        return _google_translate(text)
    except Exception as exc:
        log.exception("partial translate failed")
        raise RuntimeError(f"partial translate failed: {exc}") from exc


def _translate_final_uncached(
    mode: str, text: str, draft_zh: Optional[str]
) -> str:
    text = text.strip()
    if not text:
        return ""
    mode = normalize_mode(mode)
    if mode == "dual":
        try:
            return qiniu_translate(text, draft_zh)
        except Exception as exc:
            log.warning("Qiniu final failed (dual), fallback: %s", exc)
        try:
            return tmt_translate(text)
        except Exception as exc:
            log.warning("TMT final fallback failed: %s", exc)
    elif mode == "tencent":
        try:
            return tmt_translate(text)
        except Exception as exc:
            log.warning("TMT final failed, fallback: %s", exc)
    elif mode == "qiniu":
        try:
            return qiniu_translate(text, draft_zh)
        except Exception as exc:
            log.warning("Qiniu final failed, fallback: %s", exc)
    elif mode in ("argos", "opus"):
        try:
            return _offline_translate(mode, text)
        except Exception as exc:
            log.exception("offline final failed (%s)", mode)
            raise RuntimeError(f"offline translate failed: {exc}") from exc
    try:
        return _google_translate(text)
    except Exception as exc:
        log.exception("final translate failed")
        raise RuntimeError(f"final translate failed: {exc}") from exc


def translate_partial(text: str, mode: str | None = None) -> str:
    m = normalize_mode(mode or default_mode())
    return _cached_partial(m, text.strip())


def translate_final(
    text: str, draft_zh: Optional[str] = None, mode: str | None = None
) -> str:
    m = normalize_mode(mode or default_mode())
    return _cached_final(m, text.strip(), (draft_zh or "").strip())


def translate(text: str, mode: str | None = None) -> str:
    return translate_partial(text, mode)


def get_translate_status(mode: str | None = None) -> dict[str, Any]:
    return get_status(mode)
