"""Provider verify gate — engine dropdown shows only test-passed providers."""

from __future__ import annotations

import os

from provider_registry import LAYER_PROVIDERS, NO_KEY_PROVIDERS


def _verified_key(layer: str, provider_id: str) -> str:
    return f"VERIFIED_{layer.upper()}_{provider_id.upper()}"


def is_verified(layer: str, provider_id: str) -> bool:
    return os.getenv(_verified_key(layer, provider_id), "").strip() == "1"


def set_verified(layer: str, provider_id: str, verified: bool) -> None:
    key = _verified_key(layer, provider_id)
    if verified:
        os.environ[key] = "1"
    else:
        os.environ.pop(key, None)


def credentials_ok(layer: str, provider_id: str) -> bool:
    if provider_id in NO_KEY_PROVIDERS:
        return True
    if layer == "asr" and provider_id == "tencent":
        from tencent_asr import configured

        return configured()
    if layer == "asr" and provider_id == "openai":
        from openai_asr import configured

        return configured()
    if provider_id == "tmt":
        from translate_tmt import configured

        return configured()
    if provider_id == "baidu":
        from translate_baidu import configured

        return configured()
    if provider_id == "deepl":
        from translate_deepl import configured

        return configured()
    if provider_id == "qiniu":
        from translate_qiniu import configured

        return configured()
    if provider_id in ("aliyun", "deepseek", "openai"):
        mod = {
            "aliyun": "translate_aliyun",
            "deepseek": "translate_deepseek",
            "openai": "translate_openai",
        }[provider_id]
        return __import__(mod, fromlist=["configured"]).configured()
    return False


def verified_status() -> dict[str, list[str]]:
    out: dict[str, list[str]] = {}
    for layer, ids in LAYER_PROVIDERS.items():
        out[layer] = [pid for pid in ids if is_verified(layer, pid)]
    return out
