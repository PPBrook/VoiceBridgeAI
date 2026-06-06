"""Selectable final translation / polish providers."""

from __future__ import annotations

import os
from typing import Any

FINAL_PROVIDERS = (
    {"id": "qiniu", "label": "七牛 AI · LLM 润色"},
    {"id": "aliyun", "label": "阿里云 DashScope · LLM 润色"},
    {"id": "tmt", "label": "腾讯 TMT · 机器翻译"},
    {"id": "google", "label": "Google 在线"},
    {"id": "argos", "label": "Argos 离线"},
    {"id": "none", "label": "不润色（沿用句中）"},
)

_VALID = frozenset(p["id"] for p in FINAL_PROVIDERS)


def default_provider() -> str:
    env = os.getenv("FINAL_PROVIDER", "").strip()
    if env in _VALID:
        return env
    legacy = os.getenv("LLM_PROVIDER", "").strip()
    if legacy in ("qiniu", "aliyun"):
        return legacy
    legacy_tr = os.getenv("TRANSLATE_MODE", "").strip()
    if legacy_tr == "dual":
        return "qiniu"
    if legacy_tr == "argos":
        return "argos"
    if legacy_tr == "local":
        return "google"
    return "qiniu"


def normalize_provider(provider: str | None) -> str:
    if provider in _VALID:
        return provider  # type: ignore[return-value]
    return default_provider()


def set_provider(provider: str | None) -> None:
    if provider in _VALID:
        os.environ["FINAL_PROVIDER"] = provider  # type: ignore[arg-type]
        if provider in ("qiniu", "aliyun"):
            os.environ["LLM_PROVIDER"] = provider


def configured(provider: str | None = None) -> bool:
    p = normalize_provider(provider)
    if p == "none":
        return True
    if p == "qiniu":
        from translate_qiniu import configured as qiniu_configured

        return qiniu_configured()
    if p == "aliyun":
        from translate_aliyun import configured as aliyun_configured

        return aliyun_configured()
    if p == "tmt":
        from translate_tmt import configured as tmt_configured

        return tmt_configured()
    if p == "argos":
        return True
    if p == "google":
        return True
    return False


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
        from partial_config import translate as partial_translate

        return partial_translate(text)
    if p == "qiniu":
        from translate_qiniu import translate as qiniu_translate

        return qiniu_translate(text, draft_zh)
    if p == "aliyun":
        from translate_aliyun import translate as aliyun_translate

        return aliyun_translate(text, draft_zh)
    if p == "tmt":
        from translate_tmt import translate as tmt_translate

        return tmt_translate(text)
    if p == "argos":
        from translate_argos import translate as argos_translate

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
        "tmt": "tencent-tmt",
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
    from translate_aliyun import configured as aliyun_ok
    from translate_qiniu import configured as qiniu_ok

    current = normalize_provider(None)
    model = None
    if current == "qiniu" and qiniu_ok():
        from translate_qiniu import model_name

        model = model_name()
    elif current == "aliyun" and aliyun_ok():
        from translate_aliyun import model_name

        model = model_name()

    return {
        "finalProvider": current,
        "finalProviders": list(FINAL_PROVIDERS),
        "finalConfigured": configured(current),
        "finalEngine": engine_label(current),
        "finalProviderLabel": provider_label(current),
        "finalModel": model,
        "qiniuConfigured": qiniu_ok(),
        "aliyunConfigured": aliyun_ok(),
    }
