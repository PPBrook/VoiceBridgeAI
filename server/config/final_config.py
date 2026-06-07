"""Selectable final translation / polish providers."""

from __future__ import annotations

import os
from typing import Any

from providers.provider_registry import FINAL_PROVIDERS

_VALID = frozenset(p["id"] for p in FINAL_PROVIDERS)


def available_providers() -> list[dict[str, str]]:
    from providers.provider_enable import is_verified

    return [dict(item) for item in FINAL_PROVIDERS if is_verified("final", item["id"])]


def default_provider() -> str:
    env = os.getenv("FINAL_PROVIDER", "").strip()
    available = {p["id"] for p in available_providers()}
    if env in available:
        return env
    legacy = os.getenv("LLM_PROVIDER", "").strip()
    if legacy in available:
        return legacy
    legacy_tr = os.getenv("TRANSLATE_MODE", "").strip()
    if legacy_tr == "dual" and "qiniu" in available:
        return "qiniu"
    if legacy_tr == "argos" and "argos" in available:
        return "argos"
    if legacy_tr == "argos" and "none" in available:
        return "none"
    if legacy_tr == "local" and "google" in available:
        return "google"
    if "qiniu" in available:
        return "qiniu"
    if "argos" in available:
        return "argos"
    if "none" in available:
        return "none"
    return available[0]["id"] if available else ""


def normalize_provider(provider: str | None) -> str:
    available = {p["id"] for p in available_providers()}
    if provider and provider in available:
        return provider  # type: ignore[return-value]
    env = os.getenv("FINAL_PROVIDER", "").strip()
    if env in available:
        return env  # type: ignore[return-value]
    modes = available_providers()
    return modes[0]["id"] if modes else ""


def configured(provider: str | None = None) -> bool:
    from providers.provider_enable import is_verified

    p = normalize_provider(None) if provider is None else provider
    if p not in _VALID:
        return False
    return is_verified("final", p)


def set_provider(provider: str | None) -> None:
    if provider in _VALID:
        os.environ["FINAL_PROVIDER"] = provider  # type: ignore[arg-type]
        if provider in ("qiniu", "aliyun", "deepseek", "openai"):
            os.environ["LLM_PROVIDER"] = provider


def translate(
    text: str,
    draft_zh: str | None = None,
    provider: str | None = None,
) -> str:
    text = text.strip()
    if not text:
        return ""
    p = normalize_provider(provider)
    if p == "none":
        if draft_zh and draft_zh.strip():
            return draft_zh.strip()
        from config.partial_config import translate as partial_translate

        return partial_translate(text)
    if p == "qiniu":
        from providers.translate_qiniu import translate as qiniu_translate

        return qiniu_translate(text, draft_zh)
    if p == "aliyun":
        from providers.translate_aliyun import translate as aliyun_translate

        return aliyun_translate(text, draft_zh)
    if p == "deepseek":
        from providers.translate_deepseek import translate as deepseek_translate

        return deepseek_translate(text, draft_zh)
    if p == "openai":
        from providers.translate_openai import translate as openai_translate

        return openai_translate(text, draft_zh)
    if p == "tmt":
        from providers.translate_tmt import translate as tmt_translate

        return tmt_translate(text)
    if p == "baidu":
        from providers.translate_baidu import translate as baidu_translate

        return baidu_translate(text)
    if p == "deepl":
        from providers.translate_deepl import translate as deepl_translate

        return deepl_translate(text, draft_zh)
    if p == "argos":
        from providers.translate_argos import translate as argos_translate

        return argos_translate(text)
    if p == "google":
        from deep_translator import GoogleTranslator

        return GoogleTranslator(source="en", target="zh-CN").translate(text)
    raise RuntimeError(f"unknown final provider: {p}")


def engine_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    return {
        "qiniu": "qiniu-llm",
        "aliyun": "aliyun-llm",
        "deepseek": "deepseek-llm",
        "openai": "openai-llm",
        "tmt": "tencent-tmt",
        "baidu": "baidu-mt",
        "deepl": "deepl",
        "google": "google",
        "argos": "argos-offline",
        "none": "same-as-partial",
    }.get(p, p)


def provider_label(provider: str | None = None) -> str:
    p = normalize_provider(provider)
    for item in FINAL_PROVIDERS:
        if item["id"] == p:
            return item["label"]
    return p


def get_status() -> dict[str, Any]:
    from providers.translate_aliyun import configured as aliyun_ok
    from providers.translate_baidu import configured as baidu_ok
    from providers.translate_deepseek import configured as deepseek_ok
    from providers.translate_deepl import configured as deepl_ok
    from providers.translate_openai import configured as openai_ok
    from providers.translate_qiniu import configured as qiniu_ok

    current = normalize_provider(None)
    model = None
    if current == "qiniu" and qiniu_ok():
        from providers.translate_qiniu import model_name

        model = model_name()
    elif current == "aliyun" and aliyun_ok():
        from providers.translate_aliyun import model_name

        model = model_name()
    elif current == "deepseek" and deepseek_ok():
        from providers.translate_deepseek import model_name

        model = model_name()
    elif current == "openai" and openai_ok():
        from providers.translate_openai import model_name

        model = model_name()

    return {
        "finalProvider": current,
        "finalProviders": available_providers(),
        "finalConfigured": configured(current),
        "finalEngine": engine_label(current),
        "finalProviderLabel": provider_label(current),
        "finalModel": model,
        "qiniuConfigured": qiniu_ok(),
        "aliyunConfigured": aliyun_ok(),
        "deepseekConfigured": deepseek_ok(),
        "openaiTranslateConfigured": openai_ok(),
        "baiduConfigured": baidu_ok(),
        "deeplConfigured": deepl_ok(),
    }
