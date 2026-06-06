"""Runtime cloud API configuration (Tencent / Qiniu / Aliyun)."""

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
    from translate_tmt import reset_client

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


def apply_cloud(payload: dict[str, Any]) -> None:
    apply_tencent(payload.get("tencent"))
    apply_qiniu(payload.get("qiniu"))
    apply_aliyun(payload.get("aliyun"))
    from engine_config import apply_settings

    apply_settings(payload)


def tencent_status() -> dict[str, Any]:
    from tencent_asr import configured as asr_configured, engine_model
    from translate_tmt import configured as tmt_configured, region as tmt_region

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
    from translate_qiniu import base_url, configured, model_name

    return {
        "configured": configured(),
        "baseUrl": base_url(),
        "model": model_name(),
        "hasApiKey": bool(os.getenv("QINIU_AI_API_KEY", "").strip()),
    }


def aliyun_status() -> dict[str, Any]:
    from translate_aliyun import base_url, configured, model_name

    return {
        "configured": configured(),
        "baseUrl": base_url(),
        "model": model_name(),
        "hasApiKey": bool(os.getenv("ALIYUN_AI_API_KEY", "").strip()),
    }


def cloud_status() -> dict[str, Any]:
    return {
        "tencent": tencent_status(),
        "qiniu": qiniu_status(),
        "aliyun": aliyun_status(),
    }
