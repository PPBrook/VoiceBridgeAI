"""Unified engine settings: ASR / partial translation / final polish."""

from __future__ import annotations

from typing import Any

from asr_config import get_status as asr_status
from asr_config import normalize_mode as normalize_asr
from asr_config import set_provider as set_asr
from final_config import get_status as final_status
from final_config import set_provider as set_final
from partial_config import get_status as partial_status
from partial_config import set_provider as set_partial


def apply_settings(payload: dict[str, Any]) -> None:
    from env_persist import persist_engine_config
    from final_config import available_providers as final_available
    from partial_config import normalize_provider as norm_partial
    from provider_registry import resolve_final_provider

    asr = payload.get("asrProvider") or payload.get("asrMode")
    if asr:
        set_asr(asr)
    partial_id = payload.get("partialProvider")
    if partial_id:
        set_partial(partial_id)
    final = payload.get("finalProvider") or payload.get("llmProvider")
    if final or partial_id:
        partial = norm_partial(partial_id) if partial_id else norm_partial(None)
        available = {p["id"] for p in final_available()}
        resolved = resolve_final_provider(partial, final, available)
        if resolved:
            set_final(resolved)
    persist_engine_config(payload)


def get_engine_status(asr_mode: str | None = None) -> dict[str, Any]:
    from translate_tmt import configured as tmt_configured
    from translate_tmt import region as tmt_region

    asr = asr_status(asr_mode)
    partial = partial_status()
    final = final_status()

    from provider_registry import LLM_PROVIDERS, REPEAT_MT_PROVIDERS, engine_pair_note, filter_final_providers, resolve_final_provider
    from final_config import provider_label

    partial_id = partial["partialProvider"]
    final_id = final["finalProvider"]
    available_final = {p["id"] for p in final["finalProviders"]}
    resolved_final = resolve_final_provider(partial_id, final_id, available_final)
    if resolved_final != final_id:
        final_id = resolved_final
        from final_config import engine_label

        final = {
            **final,
            "finalProvider": resolved_final,
            "finalProviderLabel": provider_label(resolved_final),
            "finalEngine": engine_label(resolved_final),
        }
    return {
        **asr,
        **partial,
        **final,
        "finalProvidersFiltered": filter_final_providers(
            final["finalProviders"],
            partial_id,
        ),
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
        "engineRules": {
            "llmProviders": sorted(LLM_PROVIDERS),
            "repeatMtProviders": sorted(REPEAT_MT_PROVIDERS),
            "pairNote": engine_pair_note(partial_id, final_id),
        },
    }
