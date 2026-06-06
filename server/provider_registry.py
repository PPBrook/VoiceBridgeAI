"""Single source of truth for provider ids, labels, and layer membership."""

from __future__ import annotations

ASR_MODES = (
    {"id": "tencent", "label": "腾讯云 · 国内流式"},
    {"id": "openai", "label": "OpenAI Whisper · 海外云端"},
    {"id": "local", "label": "Whisper · 本地离线"},
)

PARTIAL_PROVIDERS = (
    {"id": "tmt", "label": "腾讯 TMT · 国内"},
    {"id": "baidu", "label": "百度翻译 · 国内"},
    {"id": "qiniu", "label": "七牛 AI · 国内 LLM"},
    {"id": "aliyun", "label": "阿里云 DashScope · 国内 LLM"},
    {"id": "deepseek", "label": "DeepSeek · 国内 LLM"},
    {"id": "google", "label": "Google · 海外"},
    {"id": "deepl", "label": "DeepL · 海外"},
    {"id": "openai", "label": "OpenAI · 海外 LLM"},
    {"id": "argos", "label": "Argos · 离线"},
)

FINAL_PROVIDERS = (
    {"id": "qiniu", "label": "七牛 AI · 国内 LLM"},
    {"id": "aliyun", "label": "阿里云 DashScope · 国内 LLM"},
    {"id": "deepseek", "label": "DeepSeek · 国内 LLM"},
    {"id": "tmt", "label": "腾讯 TMT · 国内"},
    {"id": "baidu", "label": "百度翻译 · 国内"},
    {"id": "deepl", "label": "DeepL · 海外"},
    {"id": "openai", "label": "OpenAI · 海外 LLM"},
    {"id": "google", "label": "Google · 海外"},
    {"id": "argos", "label": "Argos · 离线"},
    {"id": "none", "label": "不润色（沿用句中）"},
)

LAYER_PROVIDERS: dict[str, tuple[str, ...]] = {
    "asr": tuple(m["id"] for m in ASR_MODES),
    "partial": tuple(p["id"] for p in PARTIAL_PROVIDERS),
    "final": tuple(p["id"] for p in FINAL_PROVIDERS),
}

NO_KEY_PROVIDERS = frozenset({"local", "argos", "google", "none"})

# LLM providers may appear on both layers (draft vs polish); MT should differ.
LLM_PROVIDERS = frozenset({"qiniu", "aliyun", "deepseek", "openai"})


def allows_same_layer_provider(provider_id: str) -> bool:
    return provider_id in LLM_PROVIDERS


def filter_final_providers(
    providers: tuple[dict[str, str], ...] | list[dict[str, str]],
    partial_id: str,
) -> list[dict[str, str]]:
    if not partial_id or allows_same_layer_provider(partial_id):
        return [dict(p) for p in providers]
    skip = {partial_id, "none"}
    others = [dict(p) for p in providers if p["id"] not in skip]
    return others if others else [dict(p) for p in providers]


def filter_partial_providers(
    providers: tuple[dict[str, str], ...] | list[dict[str, str]],
    final_id: str,
) -> list[dict[str, str]]:
    if not final_id or final_id == "none" or allows_same_layer_provider(final_id):
        return [dict(p) for p in providers]
    others = [dict(p) for p in providers if p["id"] != final_id]
    return others if others else [dict(p) for p in providers]


def resolve_final_provider(
    partial_id: str,
    final_id: str | None,
    available_ids: set[str] | frozenset[str] | None = None,
) -> str:
    """Avoid redundant MT+MT pairs; keep LLM+LLM when intentional."""
    from final_config import normalize_provider

    final = normalize_provider(final_id) if final_id else normalize_provider(None)
    if not partial_id:
        return final
    if final == partial_id and not allows_same_layer_provider(partial_id):
        pool = available_ids or {final}
        for item in filter_final_providers([{"id": x, "label": x} for x in pool], partial_id):
            if item["id"] in pool:
                return item["id"]
    if available_ids and final not in available_ids:
        filtered = filter_final_providers(
            [{"id": x, "label": x} for x in available_ids],
            partial_id,
        )
        if filtered:
            return filtered[0]["id"]
    return final


def engine_pair_note(partial_id: str, final_id: str) -> str | None:
    if not partial_id or not final_id:
        return None
    if partial_id == final_id:
        if allows_same_layer_provider(partial_id):
            return "句中快译 + 句末润色（同一 LLM，模式不同）。"
        return "仅该接口可用，句末与句中相同，不会做额外润色。"
    if final_id == "none":
        return "句末不润色，沿用句中译文。"
    return None
