"""Tencent Cloud Machine Translation (TMT) — fast partial translation."""

from __future__ import annotations

import json
import logging
import os
from typing import Optional

log = logging.getLogger(__name__)

_client = None


def _secret_id() -> str:
    return (
        os.getenv("TENCENT_ASR_SECRET_ID", "").strip()
        or os.getenv("TENCENT_SECRET_ID", "").strip()
    )


def _secret_key() -> str:
    return (
        os.getenv("TENCENT_ASR_SECRET_KEY", "").strip()
        or os.getenv("TENCENT_SECRET_KEY", "").strip()
    )


def configured() -> bool:
    return bool(_secret_id() and _secret_key())


def region() -> str:
    return os.getenv("TMT_REGION", "ap-guangzhou").strip() or "ap-guangzhou"


def reset_client() -> None:
    global _client
    _client = None


def _client_instance():
    global _client
    if _client is not None:
        return _client
    from tencentcloud.common import credential
    from tencentcloud.common.profile.client_profile import ClientProfile
    from tencentcloud.common.profile.http_profile import HttpProfile
    from tencentcloud.tmt.v20180321 import tmt_client

    cred = credential.Credential(_secret_id(), _secret_key())
    http = HttpProfile(endpoint="tmt.tencentcloudapi.com")
    profile = ClientProfile(httpProfile=http)
    _client = tmt_client.TmtClient(cred, region(), profile)
    return _client


def translate(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    if not configured():
        raise RuntimeError("Tencent TMT not configured")

    from tencentcloud.tmt.v20180321 import models

    req = models.TextTranslateRequest()
    req.from_json_string(
        json.dumps(
            {
                "SourceText": text,
                "Source": "en",
                "Target": "zh",
                "ProjectId": int(os.getenv("TMT_PROJECT_ID", "0") or 0),
            }
        )
    )
    try:
        resp = _client_instance().TextTranslate(req)
        return (resp.TargetText or "").strip()
    except Exception as exc:
        log.exception("tencent tmt failed")
        raise RuntimeError(f"Tencent TMT error: {exc}") from exc
