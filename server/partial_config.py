"""Selectable partial (draft) translation providers."""

from __future__ import annotations

import os
from typing import Any

PARTIAL_PROVIDERS = (
    {"id": "tmt", "label": "腾讯 TMT · 机器翻译"},
    {"id": "google", "label": "Google 在线"},
    {"id": "argos", "label": "Argos 离线"},
    {"id": "aliyun", "label": "阿里云 DashScope · LLM"},
)

_VALID = frozenset(p["id"] for p in PARTIAL_PROVIDERS)


def default_provider() -> str:
    env = os.getenv("PARTIAL_PROVIDER", "").strip()
    if env in _VALID:
        return env
    # legacy TRANSLATE_MODE
    legacy = os.getenv("TRANSLATE_MODE", "").strip()
    if legacy == "dual":
        return "tmt"
    if legacy == "argos":
        return "argos"
    if legacy == "local":
        return "google"
    from translate_tmt import configured as tmt_ok

    return "tmt" if tmt_ok() else "google"


def normalize_provider(provider: str | None) -> str:
    if provider in _VALID:
        return provider  # type: ignore[return-value]
    return default_provider()


def set_provider(provider: str | None) -> None:
    if provider in _VALID:
        os.environ["PARTIAL_PROVIDER"] = provider  # type: ignore[arg-type]


def configured(provider: str | None = None) -> bool:
    p = normalize_provider(provider)
    if p == "tmt":
        from translate_tmt import configured as tmt_configured

        return tmt_configured()
    if p == "argos":
        return True
    if p == "google":
        return True
    if p == "aliyun":
        from translate_aliyun import configured as aliyun_configured

        return aliyun_configured()
    return False


def translate(text: str, provider: str | None = None) -> str:
    text = text.strip()
    if not text:
        return ""
    p = normalize_provider(provider)
    if p == "tmt":
        from translate_tmt import translate as tmt_translate

        return tmt_translate(text)
    if p == "argos":
        from translate_argos import translate as argos_translate

        return argos_translate(text)
    if p == "google":
        from deep_translator import GoogleTranslator

        return GoogleTranslator(source="en", target="zh-CN").translate(text)
    if p == "aliyun":
        from translate_aliyun import translate as aliyun_translate

        return aliyun_translate(text, None)
    raise RuntimeError(f"unknown partial provider: {p}")


def engine_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    return {
        "tmt": "tencent-tmt",
        "google": "google",
        "argos": "argos-offline",
        "aliyun": "aliyun-llm",
    }.get(p, p)


def provider_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    for item in PARTIAL_PROVIDERS:
        if item["id"] == p:
            return item["label"]
    return p


def get_status() -> dict[str, Any]:
    current = normalize_provider(None)
    return {
        "partialProvider": current,
        "partialProviders": list(PARTIAL_PROVIDERS),
        "partialConfigured": configured(current),
        "partialEngine": engine_label(current),
        "partialProviderLabel": provider_label(current),
    }
