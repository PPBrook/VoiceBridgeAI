"""Selectable partial (draft) translation providers."""

from __future__ import annotations

import os
from typing import Any

from providers.provider_registry import PARTIAL_PROVIDERS

_VALID = frozenset(p["id"] for p in PARTIAL_PROVIDERS)


def available_providers() -> list[dict[str, str]]:
    from providers.provider_enable import is_verified

    return [dict(item) for item in PARTIAL_PROVIDERS if is_verified("partial", item["id"])]


def default_provider() -> str:
    env = os.getenv("PARTIAL_PROVIDER", "").strip()
    available = {p["id"] for p in available_providers()}
    if env in available:
        return env
    legacy = os.getenv("TRANSLATE_MODE", "").strip()
    if legacy == "dual" and "tmt" in available:
        return "tmt"
    if legacy == "argos" and "argos" in available:
        return "argos"
    if legacy == "local" and "google" in available:
        return "google"
    if "tmt" in available:
        return "tmt"
    if "argos" in available:
        return "argos"
    return available[0]["id"] if available else ""


def normalize_provider(provider: str | None) -> str:
    if provider in _VALID:
        return provider  # type: ignore[return-value]
    available = {p["id"] for p in available_providers()}
    if provider in available:
        return provider  # type: ignore[return-value]
    env = os.getenv("PARTIAL_PROVIDER", "").strip()
    if env in available:
        return env
    modes = available_providers()
    return modes[0]["id"] if modes else ""


def configured(provider: str | None = None) -> bool:
    from providers.provider_enable import is_verified

    p = normalize_provider(None) if provider is None else provider
    if p not in _VALID:
        return False
    return is_verified("partial", p)


def set_provider(provider: str | None) -> None:
    if provider in _VALID:
        os.environ["PARTIAL_PROVIDER"] = provider  # type: ignore[arg-type]


def translate(text: str, provider: str | None = None) -> str:
    text = text.strip()
    if not text:
        return ""
    p = normalize_provider(provider)
    if p == "tmt":
        from providers.translate_tmt import translate as tmt_translate

        return tmt_translate(text)
    if p == "baidu":
        from providers.translate_baidu import translate as baidu_translate

        return baidu_translate(text)
    if p == "qiniu":
        from providers.translate_qiniu import translate as qiniu_translate

        return qiniu_translate(text, None, polish=False)
    if p == "argos":
        from providers.translate_argos import translate as argos_translate

        return argos_translate(text)
    if p == "google":
        from deep_translator import GoogleTranslator

        return GoogleTranslator(source="en", target="zh-CN").translate(text)
    if p == "deepl":
        from providers.translate_deepl import translate as deepl_translate

        return deepl_translate(text)
    if p == "aliyun":
        from providers.translate_aliyun import translate as aliyun_translate

        return aliyun_translate(text, None, polish=False)
    if p == "deepseek":
        from providers.translate_deepseek import translate as deepseek_translate

        return deepseek_translate(text, None, polish=False)
    if p == "openai":
        from providers.translate_openai import translate as openai_translate

        return openai_translate(text, None, polish=False)
    raise RuntimeError(f"unknown partial provider: {p}")


def engine_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    return {
        "tmt": "tencent-tmt",
        "baidu": "baidu-mt",
        "qiniu": "qiniu-llm",
        "google": "google",
        "deepl": "deepl",
        "argos": "argos-offline",
        "aliyun": "aliyun-llm",
        "deepseek": "deepseek-llm",
        "openai": "openai-llm",
    }.get(p, p)


def provider_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    for item in PARTIAL_PROVIDERS:
        if item["id"] == p:
            return item["label"]
    return p


def get_status() -> dict[str, Any]:
    from providers.translate_baidu import configured as baidu_ok
    from providers.translate_deepseek import configured as deepseek_ok
    from providers.translate_deepl import configured as deepl_ok
    from providers.translate_openai import configured as openai_ok

    current = normalize_provider(None)
    providers = available_providers()
    return {
        "partialProvider": current,
        "partialProviders": providers,
        "partialConfigured": configured(current),
        "partialEngine": engine_label(current),
        "partialProviderLabel": provider_label(current),
        "baiduConfigured": baidu_ok(),
        "deeplConfigured": deepl_ok(),
        "deepseekConfigured": deepseek_ok(),
        "openaiTranslateConfigured": openai_ok(),
    }
