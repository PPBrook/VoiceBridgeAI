"""Revise / lookback presets (speed vs accuracy)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

REVISE_MODES = (
    {"id": "speed", "label": "实时优先 · 低延迟"},
    {"id": "balanced", "label": "标准纠正 · 推荐"},
    {"id": "accuracy", "label": "精准纠正 · 深度回溯"},
)

_VALID = frozenset(m["id"] for m in REVISE_MODES)


@dataclass(frozen=True)
class ReviseParams:
    debounce_s: float
    lookback: int
    refine_interval_s: float
    min_chars: int = 3


PRESETS: dict[str, ReviseParams] = {
    "speed": ReviseParams(debounce_s=0.35, lookback=0, refine_interval_s=1.2),
    "balanced": ReviseParams(debounce_s=0.25, lookback=2, refine_interval_s=0.8),
    "accuracy": ReviseParams(debounce_s=0.15, lookback=3, refine_interval_s=0.55),
}


def default_mode() -> str:
    env = os.getenv("REVISE_MODE", "").strip()
    if env in _VALID:
        return env
    return "balanced"


def normalize_mode(mode: str | None) -> str:
    if mode in _VALID:
        return mode  # type: ignore[return-value]
    return default_mode()


def get_params(mode: str | None = None) -> ReviseParams:
    return PRESETS[normalize_mode(mode)]


def get_status(mode: str | None = None) -> dict[str, Any]:
    current = normalize_mode(mode)
    params = get_params(current)
    return {
        "reviseMode": current,
        "reviseModes": list(REVISE_MODES),
        "reviseLookback": params.lookback,
        "reviseDebounce": params.debounce_s,
        "reviseRefineInterval": params.refine_interval_s,
    }
