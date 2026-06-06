"""Unified engine settings: ASR / partial translation / final polish."""

from __future__ import annotations

import os
from typing import Any

from asr_config import get_status as asr_status
from asr_config import normalize_mode as normalize_asr
from asr_config import set_provider as set_asr
from final_config import get_status as final_status
from final_config import set_provider as set_final
from partial_config import get_status as partial_status
from partial_config import set_provider as set_partial

# 快速预设（控制台「路径 A/B/C」）
ENGINE_PRESETS = (
    {"id": "dual", "label": "路径 A · 云端双擎"},
    {"id": "argos", "label": "路径 B · 全本地"},
    {"id": "local", "label": "路径 C · 联网兜底"},
)

_PRESET_VALUES: dict[str, dict[str, str]] = {
    "dual": {"asr": "tencent", "partial": "tmt", "final": "qiniu"},
    "argos": {"asr": "local", "partial": "argos", "final": "argos"},
    "local": {"asr": "local", "partial": "google", "final": "google"},
}


def apply_settings(payload: dict[str, Any]) -> None:
    preset_id = payload.get("translateMode") or payload.get("enginePreset")
    if preset_id and preset_id in _PRESET_VALUES:
        values = _PRESET_VALUES[preset_id]
        os.environ["ENGINE_PRESET"] = preset_id
        set_asr(values["asr"])
        set_partial(values["partial"])
        set_final(values["final"])
        return

    os.environ.pop("ENGINE_PRESET", None)
    asr = payload.get("asrProvider") or payload.get("asrMode")
    if asr:
        set_asr(asr)
    if payload.get("partialProvider"):
        set_partial(payload["partialProvider"])
    final = payload.get("finalProvider") or payload.get("llmProvider")
    if final:
        set_final(final)


def get_engine_status(asr_mode: str | None = None) -> dict[str, Any]:
    from translate_tmt import configured as tmt_configured
    from translate_tmt import region as tmt_region

    asr = asr_status(asr_mode)
    partial = partial_status()
    final = final_status()

    preset_id = os.getenv("ENGINE_PRESET", "").strip()
    if preset_id not in _PRESET_VALUES:
        preset_id = ""
        for pid, values in _PRESET_VALUES.items():
            if (
                values["partial"] == partial["partialProvider"]
                and values["final"] == final["finalProvider"]
                and (
                    values["asr"] == asr["asrMode"]
                    or (
                        values["asr"] == "tencent"
                        and asr["asrMode"] == "local"
                    )
                )
            ):
                # asr 因未配置腾讯云时 normalize 会落到 local，仍视为同预设
                preset_id = pid
                break

    return {
        **asr,
        **partial,
        **final,
        "enginePreset": preset_id or None,
        "enginePresets": list(ENGINE_PRESETS),
        "translatePartial": partial["partialEngine"],
        "translateFinal": final["finalEngine"],
        "asrProvider": asr["asrMode"],
        "asrProviderLabel": next(
            (m["label"] for m in asr["asrModes"] if m["id"] == asr["asrMode"]),
            asr["asrMode"],
        ),
        "tmtConfigured": tmt_configured(),
        "tmtRegion": tmt_region() if tmt_configured() else None,
        "offlineTranslate": partial["partialProvider"] == "argos",
    }


def normalize_asr_mode(mode: str | None) -> str:
    return normalize_asr(mode)
