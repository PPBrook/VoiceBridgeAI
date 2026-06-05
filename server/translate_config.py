"""Translation backend selection and status."""

from __future__ import annotations

import os
from typing import Any

from translate_qiniu import configured as qiniu_configured
from translate_qiniu import model_name as qiniu_model
from translate_tmt import configured as tmt_configured
from translate_tmt import region as tmt_region

# 页面展示（定版 3 项）
UI_TRANSLATE_MODES = (
    {"id": "dual", "label": "云端双擎翻译 · 快译+润色"},
    {"id": "argos", "label": "本地离线翻译 · 无需密钥"},
    {"id": "local", "label": "联网在线翻译 · 免费兜底"},
)

_UI_IDS = frozenset(m["id"] for m in UI_TRANSLATE_MODES)
# 内部仍支持（env 兼容，不在 UI 展示）：tencent | qiniu | opus
_LEGACY_IDS = frozenset({"tencent", "qiniu", "opus"})
_VALID = _UI_IDS | _LEGACY_IDS
_OFFLINE = frozenset({"argos", "opus"})


def _dual_available() -> bool:
    return tmt_configured() and qiniu_configured()


def to_ui_mode(mode: str | None) -> str:
    """Map internal / legacy mode to a UI dropdown value."""
    m = normalize_mode(mode)
    if m in _UI_IDS:
        return m
    if m == "opus":
        return "argos"
    if m in ("tencent", "qiniu") and _dual_available():
        return "dual"
    return "local"


def default_mode() -> str:
    env = os.getenv("TRANSLATE_MODE", "").strip()
    if env in _VALID:
        return to_ui_mode(env)
    if _dual_available():
        return "dual"
    return "argos"


def normalize_mode(mode: str | None) -> str:
    if mode == "dual":
        if _dual_available():
            return "dual"
        if tmt_configured():
            return "tencent"
        if qiniu_configured():
            return "qiniu"
        return "argos"
    if mode == "tencent":
        return "tencent" if tmt_configured() else to_ui_mode(None)
    if mode == "qiniu":
        return "qiniu" if qiniu_configured() else to_ui_mode(None)
    if mode in _OFFLINE | {"local"}:
        return mode  # type: ignore[return-value]
    return default_mode()


def _engines_for(mode: str) -> tuple[str, str]:
    mode = normalize_mode(mode)
    if mode == "dual":
        return "tencent-tmt", "qiniu-llm"
    if mode == "tencent":
        return "tencent-tmt", "tencent-tmt"
    if mode == "qiniu":
        return "qiniu-llm", "qiniu-llm"
    if mode == "argos":
        return "argos-offline", "argos-offline"
    if mode == "opus":
        return "opus-mt-offline", "opus-mt-offline"
    return "google", "google"


def available_modes() -> list[dict[str, str]]:
    modes: list[dict[str, str]] = []
    for m in UI_TRANSLATE_MODES:
        if m["id"] == "dual" and not _dual_available():
            continue
        modes.append(dict(m))
    return modes


def get_status(mode: str | None = None) -> dict[str, Any]:
    internal = normalize_mode(mode)
    current = to_ui_mode(mode)
    partial, final = _engines_for(internal)
    modes = available_modes()
    if not any(m["id"] == current for m in modes):
        current = modes[0]["id"]
        internal = normalize_mode(current)
        partial, final = _engines_for(internal)
    return {
        "translateMode": current,
        "translateModes": modes,
        "translatePartial": partial,
        "translateFinal": final,
        "tmtConfigured": tmt_configured(),
        "qiniuConfigured": qiniu_configured(),
        "qiniuModel": qiniu_model() if qiniu_configured() else None,
        "tmtRegion": tmt_region() if tmt_configured() else None,
        "offlineTranslate": current == "argos",
    }
