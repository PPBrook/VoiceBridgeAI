"""Provider verify gate — engine dropdown shows only test-passed providers."""

from __future__ import annotations

import os

from providers.provider_registry import DEFAULT_AVAILABLE, LAYER_PROVIDERS, NO_KEY_PROVIDERS


def _verified_key(layer: str, provider_id: str) -> str:
    return f"VERIFIED_{layer.upper()}_{provider_id.upper()}"


def is_default_available(layer: str, provider_id: str) -> bool:
    return provider_id in DEFAULT_AVAILABLE.get(layer, frozenset())


def is_verified(layer: str, provider_id: str) -> bool:
    from core.local_models import optional_local_models_enabled

    if optional_local_models_enabled():
        if layer == "asr" and provider_id == "local":
            from core.local_models import is_model_available

            return is_model_available("whisper")
        if provider_id == "argos":
            from core.local_models import is_model_available

            return is_model_available("argos")
    if is_default_available(layer, provider_id):
        return True
    return os.getenv(_verified_key(layer, provider_id), "").strip() == "1"


def set_verified(layer: str, provider_id: str, verified: bool) -> None:
    if is_default_available(layer, provider_id):
        return
    key = _verified_key(layer, provider_id)
    if verified:
        os.environ[key] = "1"
    else:
        os.environ.pop(key, None)
    from config.env_persist import persist_single_env

    persist_single_env(key, "1" if verified else None)


def credentials_ok(layer: str, provider_id: str) -> bool:
    if provider_id in NO_KEY_PROVIDERS:
        return True
    if layer == "asr" and provider_id == "tencent":
        from providers.tencent_asr import configured

        return configured()
    if layer == "asr" and provider_id == "openai":
        from providers.openai_asr import configured

        return configured()
    if provider_id == "tmt":
        from providers.translate_tmt import configured

        return configured()
    if provider_id == "baidu":
        from providers.translate_baidu import configured

        return configured()
    if provider_id == "deepl":
        from providers.translate_deepl import configured

        return configured()
    if provider_id == "qiniu":
        from providers.translate_qiniu import configured

        return configured()
    if provider_id == "aliyun":
        from providers.translate_aliyun import configured

        return configured()
    if provider_id == "deepseek":
        from providers.translate_deepseek import configured

        return configured()
    if provider_id == "openai":
        from providers.translate_openai import configured

        return configured()
    return False


def verified_status() -> dict[str, list[str]]:
    """Explicitly test-passed providers (excludes built-in offline defaults)."""
    out: dict[str, list[str]] = {}
    for layer, ids in LAYER_PROVIDERS.items():
        out[layer] = [
            pid
            for pid in ids
            if not is_default_available(layer, pid)
            and os.getenv(_verified_key(layer, pid), "").strip() == "1"
        ]
    return out
