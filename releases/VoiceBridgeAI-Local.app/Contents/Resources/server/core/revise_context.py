"""Current viewing scenario for translation / polish prompts."""

from __future__ import annotations

from contextvars import ContextVar

from config.revise_config import normalize_mode, polish_hint_for_mode

_revise_mode: ContextVar[str] = ContextVar("revise_mode", default="speech")


def set_revise_mode(mode: str | None) -> None:
    _revise_mode.set(normalize_mode(mode))


def get_revise_mode() -> str:
    return _revise_mode.get()


def get_polish_scene_hint() -> str:
    return polish_hint_for_mode(get_revise_mode())
