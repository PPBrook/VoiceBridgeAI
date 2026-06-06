"""Translation routing via configurable partial / final providers."""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any, Optional

from final_config import normalize_provider as normalize_final
from final_config import translate as final_translate
from partial_config import normalize_provider as normalize_partial
from partial_config import translate as partial_translate
from engine_config import get_engine_status

log = logging.getLogger(__name__)


@lru_cache(maxsize=512)
def _cached_partial(provider: str, text: str) -> str:
    return _translate_partial_uncached(provider, text)


@lru_cache(maxsize=256)
def _cached_final(provider: str, text: str, draft: str) -> str:
    return _translate_final_uncached(provider, text, draft or None)


def _translate_partial_uncached(provider: str, text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    p = normalize_partial(provider)
    try:
        return partial_translate(text, p)
    except Exception as exc:
        log.exception("partial translate failed (%s)", p)
        if p != "google":
            try:
                return partial_translate(text, "google")
            except Exception:
                pass
        raise RuntimeError(f"partial translate failed: {exc}") from exc


def _translate_final_uncached(
    provider: str, text: str, draft_zh: Optional[str]
) -> str:
    text = text.strip()
    if not text:
        return ""
    p = normalize_final(provider)
    try:
        return final_translate(text, draft_zh, p)
    except Exception as exc:
        log.warning("final translate failed (%s): %s", p, exc)
        if p not in ("tmt", "google"):
            try:
                return final_translate(text, draft_zh, "tmt")
            except Exception:
                pass
            try:
                return final_translate(text, draft_zh, "google")
            except Exception:
                pass
        raise RuntimeError(f"final translate failed: {exc}") from exc


def translate_partial(text: str, provider: str | None = None) -> str:
    p = normalize_partial(provider)
    return _cached_partial(p, text.strip())


def translate_final(
    text: str,
    draft_zh: Optional[str] = None,
    provider: str | None = None,
) -> str:
    p = normalize_final(provider)
    return _cached_final(p, text.strip(), (draft_zh or "").strip())


def translate(text: str, provider: str | None = None) -> str:
    return translate_partial(text, provider)


def get_translate_status(mode: str | None = None) -> dict[str, Any]:
    return get_engine_status()
