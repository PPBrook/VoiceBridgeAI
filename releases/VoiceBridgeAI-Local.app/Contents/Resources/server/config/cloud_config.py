"""Runtime cloud API configuration."""

from __future__ import annotations

import os
from typing import Any


def _set_if(key: str, value: str | None) -> None:
    if value is None:
        return
    value = value.strip()
    if value:
        os.environ[key] = value


def apply_tencent(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("TENCENT_ASR_APP_ID", payload.get("appId"))
    _set_if("TENCENT_ASR_SECRET_ID", payload.get("secretId"))
    _set_if("TENCENT_ASR_SECRET_KEY", payload.get("secretKey"))
    _set_if("TENCENT_ASR_ENGINE", payload.get("engine"))
    _set_if("TMT_REGION", payload.get("tmtRegion"))
    _set_if("TMT_PROJECT_ID", payload.get("tmtProjectId"))
    from providers.translate_tmt import reset_client

    reset_client()


def apply_qiniu(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("QINIU_AI_API_KEY", payload.get("apiKey"))
    _set_if("QINIU_AI_BASE_URL", payload.get("baseUrl"))
    _set_if("QINIU_AI_MODEL", payload.get("model"))


def apply_aliyun(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("ALIYUN_AI_API_KEY", payload.get("apiKey"))
    _set_if("ALIYUN_AI_BASE_URL", payload.get("baseUrl"))
    _set_if("ALIYUN_AI_MODEL", payload.get("model"))


def apply_baidu(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("BAIDU_APP_ID", payload.get("appId"))
    _set_if("BAIDU_SECRET_KEY", payload.get("secretKey"))


def apply_deepl(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("DEEPL_API_KEY", payload.get("apiKey"))
    _set_if("DEEPL_API_URL", payload.get("apiUrl"))


def apply_deepseek(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("DEEPSEEK_API_KEY", payload.get("apiKey"))
    _set_if("DEEPSEEK_BASE_URL", payload.get("baseUrl"))
    _set_if("DEEPSEEK_MODEL", payload.get("model"))


def apply_openai(payload: dict[str, Any] | None) -> None:
    if not payload:
        return
    _set_if("OPENAI_API_KEY", payload.get("apiKey"))
    _set_if("OPENAI_BASE_URL", payload.get("baseUrl"))
    _set_if("OPENAI_MODEL", payload.get("model"))
    _set_if("OPENAI_ASR_MODEL", payload.get("asrModel"))


def apply_credentials(payload: dict[str, Any]) -> None:
    apply_tencent(payload.get("tencent"))
    apply_qiniu(payload.get("qiniu"))
    apply_aliyun(payload.get("aliyun"))
    apply_baidu(payload.get("baidu"))
    apply_deepl(payload.get("deepl"))
    apply_deepseek(payload.get("deepseek"))
    apply_openai(payload.get("openai"))


def apply_cloud(payload: dict[str, Any]) -> list[str]:
    from config.env_persist import payload_has_updates, persist_cloud_config

    if not payload_has_updates(payload):
        return ["没有可保存的内容（请填写至少一项，密钥留空表示不修改已有值）"]
    apply_credentials(payload)
    try:
        persist_cloud_config(payload)
    except OSError as exc:
        return [f"写入 .env 失败：{exc}"]
    return []


def test_and_verify(layer: str, provider_id: str, payload: dict[str, Any]) -> tuple[bool, str]:
    apply_credentials(payload)
    from providers.provider_enable import set_verified
    from providers.provider_test import test_provider

    ok, message = test_provider(layer, provider_id)
    set_verified(layer, provider_id, ok)
    return ok, message


def test_all_and_verify(payload: dict[str, Any] | None = None) -> tuple[list[dict[str, Any]], str]:
    """Test configured providers; skip cards the user marked hidden."""
    if payload:
        apply_credentials(payload)
    from config.cloud_ui_prefs import get_hidden_providers, is_target_hidden
    from providers.provider_enable import set_verified
    from providers.provider_test import iter_test_targets, test_provider

    hidden_cards: set[str] | None = None
    if payload and isinstance(payload.get("hiddenProviders"), list):
        hidden_cards = {str(x).strip() for x in payload["hiddenProviders"] if str(x).strip()}
    else:
        hidden_cards = get_hidden_providers()

    results: list[dict[str, Any]] = []
    passed = failed = skipped = 0
    for layer, provider_id in iter_test_targets():
        if is_target_hidden(layer, provider_id, hidden_cards):
            skipped += 1
            continue
        ok, message = test_provider(layer, provider_id)
        set_verified(layer, provider_id, ok)
        results.append(
            {
                "layer": layer,
                "providerId": provider_id,
                "ok": ok,
                "message": message,
            }
        )
        if ok:
            passed += 1
        else:
            failed += 1
    if not results and skipped:
        return results, f"没有可测试的接口（{skipped} 项已隐藏或未配置密钥）"
    if not results:
        return results, "没有可测试的接口（请先填写并保存密钥）"
    summary = f"测试完成：{passed} 通过，{failed} 失败"
    if skipped:
        summary += f"（已跳过 {skipped} 项隐藏接口）"
    return results, summary


def tencent_status() -> dict[str, Any]:
    from providers.tencent_asr import configured as asr_configured, engine_model
    from providers.translate_tmt import configured as tmt_configured, region as tmt_region

    app_id = os.getenv("TENCENT_ASR_APP_ID", "").strip()
    return {
        "asrConfigured": asr_configured(),
        "tmtConfigured": tmt_configured(),
        "appId": app_id or None,
        "engine": engine_model(),
        "tmtRegion": tmt_region(),
        "tmtProjectId": os.getenv("TMT_PROJECT_ID", "0").strip() or "0",
        "hasSecretId": bool(os.getenv("TENCENT_ASR_SECRET_ID", "").strip()),
        "hasSecretKey": bool(os.getenv("TENCENT_ASR_SECRET_KEY", "").strip()),
    }


def qiniu_status() -> dict[str, Any]:
    from providers.translate_qiniu import base_url, configured, model_name

    return {
        "configured": configured(),
        "baseUrl": base_url(),
        "model": model_name(),
        "hasApiKey": bool(os.getenv("QINIU_AI_API_KEY", "").strip()),
    }


def aliyun_status() -> dict[str, Any]:
    from providers.translate_aliyun import base_url, configured, model_name

    return {
        "configured": configured(),
        "baseUrl": base_url(),
        "model": model_name(),
        "hasApiKey": bool(os.getenv("ALIYUN_AI_API_KEY", "").strip()),
    }


def baidu_status() -> dict[str, Any]:
    from providers.translate_baidu import configured

    return {
        "configured": configured(),
        "appId": os.getenv("BAIDU_APP_ID", "").strip() or None,
        "hasSecretKey": bool(os.getenv("BAIDU_SECRET_KEY", "").strip()),
    }


def deepl_status() -> dict[str, Any]:
    from providers.translate_deepl import api_url, configured

    return {
        "configured": configured(),
        "apiUrl": api_url(),
        "hasApiKey": bool(os.getenv("DEEPL_API_KEY", "").strip()),
    }


def deepseek_status() -> dict[str, Any]:
    from providers.translate_deepseek import base_url, configured, model_name

    return {
        "configured": configured(),
        "baseUrl": base_url(),
        "model": model_name(),
        "hasApiKey": bool(os.getenv("DEEPSEEK_API_KEY", "").strip()),
    }


def openai_status() -> dict[str, Any]:
    from providers.openai_asr import asr_model, configured as asr_ok
    from providers.translate_openai import base_url, configured, model_name

    return {
        "configured": configured(),
        "asrConfigured": asr_ok(),
        "baseUrl": base_url(),
        "model": model_name(),
        "asrModel": asr_model(),
        "hasApiKey": bool(os.getenv("OPENAI_API_KEY", "").strip()),
    }


def cloud_status() -> dict[str, Any]:
    from config.cloud_ui_prefs import ui_prefs_status
    from providers.provider_enable import verified_status

    return {
        "tencent": tencent_status(),
        "qiniu": qiniu_status(),
        "aliyun": aliyun_status(),
        "baidu": baidu_status(),
        "deepl": deepl_status(),
        "deepseek": deepseek_status(),
        "openai": openai_status(),
        "verified": verified_status(),
        "uiPrefs": ui_prefs_status(),
    }
