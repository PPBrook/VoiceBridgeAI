"""Merge cloud credential updates into the project .env file."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
ENV_PATH = ROOT / ".env"

SECRET_FIELDS = frozenset(
    {
        "secretId",
        "secretKey",
        "apiKey",
    }
)

CREDENTIAL_ENV_MAP: dict[str, dict[str, str]] = {
    "tencent": {
        "appId": "TENCENT_ASR_APP_ID",
        "secretId": "TENCENT_ASR_SECRET_ID",
        "secretKey": "TENCENT_ASR_SECRET_KEY",
        "engine": "TENCENT_ASR_ENGINE",
        "tmtRegion": "TMT_REGION",
        "tmtProjectId": "TMT_PROJECT_ID",
    },
    "qiniu": {
        "apiKey": "QINIU_AI_API_KEY",
        "baseUrl": "QINIU_AI_BASE_URL",
        "model": "QINIU_AI_MODEL",
    },
    "aliyun": {
        "apiKey": "ALIYUN_AI_API_KEY",
        "baseUrl": "ALIYUN_AI_BASE_URL",
        "model": "ALIYUN_AI_MODEL",
    },
    "baidu": {
        "appId": "BAIDU_APP_ID",
        "secretKey": "BAIDU_SECRET_KEY",
    },
    "deepl": {
        "apiKey": "DEEPL_API_KEY",
        "apiUrl": "DEEPL_API_URL",
    },
    "deepseek": {
        "apiKey": "DEEPSEEK_API_KEY",
        "baseUrl": "DEEPSEEK_BASE_URL",
        "model": "DEEPSEEK_MODEL",
    },
    "openai": {
        "apiKey": "OPENAI_API_KEY",
        "baseUrl": "OPENAI_BASE_URL",
        "model": "OPENAI_MODEL",
        "asrModel": "OPENAI_ASR_MODEL",
    },
}


def _quote_env(value: str) -> str:
    if re.search(r'[\s#"\']', value):
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return value


def payload_env_updates(payload: dict[str, Any]) -> dict[str, str]:
    """Map submitted form fields to .env keys (skip blank secrets)."""
    updates: dict[str, str] = {}
    for section, fields in CREDENTIAL_ENV_MAP.items():
        block = payload.get(section)
        if not isinstance(block, dict):
            continue
        for field, env_key in fields.items():
            if field not in block:
                continue
            raw = block.get(field)
            if raw is None:
                continue
            value = str(raw).strip()
            if not value and field in SECRET_FIELDS:
                continue
            updates[env_key] = value
    return updates


def payload_has_updates(payload: dict[str, Any]) -> bool:
    return bool(payload_env_updates(payload))


def merge_env_file(
    path: Path,
    updates: dict[str, str],
    *,
    section_comment: str = "# --- saved from /config ---",
) -> None:
    if not updates:
        return

    lines: list[str] = []
    if path.is_file():
        lines = path.read_text(encoding="utf-8").splitlines()

    remaining = dict(updates)
    merged: list[str] = []

    for raw in lines:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            merged.append(raw)
            continue
        key, _, _ = stripped.partition("=")
        key = key.strip()
        if key in remaining:
            merged.append(f"{key}={_quote_env(remaining.pop(key))}")
        else:
            merged.append(raw)

    if remaining:
        if merged and merged[-1].strip():
            merged.append("")
        merged.append(section_comment)
        for key, value in remaining.items():
            merged.append(f"{key}={_quote_env(value)}")

    path.parent.mkdir(parents=True, exist_ok=True)
    text = "\n".join(merged)
    if text:
        text += "\n"
    path.write_text(text, encoding="utf-8")

    for key, value in updates.items():
        os.environ[key] = value


def persist_cloud_config(payload: dict[str, Any]) -> None:
    merge_env_file(ENV_PATH, payload_env_updates(payload))


ENGINE_ENV_KEYS: dict[str, str] = {
    "asrProvider": "ASR_PROVIDER",
    "asrMode": "ASR_MODE",
    "partialProvider": "PARTIAL_PROVIDER",
    "finalProvider": "FINAL_PROVIDER",
    "llmProvider": "FINAL_PROVIDER",
    "reviseMode": "REVISE_MODE",
}


def engine_env_updates(payload: dict[str, Any]) -> dict[str, str]:
    updates: dict[str, str] = {}
    asr = (payload.get("asrProvider") or payload.get("asrMode") or "").strip()
    if asr:
        updates["ASR_PROVIDER"] = asr
        updates["ASR_MODE"] = asr
    partial = (payload.get("partialProvider") or "").strip()
    if partial:
        updates["PARTIAL_PROVIDER"] = partial
    final = (payload.get("finalProvider") or payload.get("llmProvider") or "").strip()
    if final:
        updates["FINAL_PROVIDER"] = final
    revise = (payload.get("reviseMode") or "").strip()
    if revise:
        updates["REVISE_MODE"] = revise
    return updates


def persist_engine_config(payload: dict[str, Any]) -> None:
    updates = engine_env_updates(payload)
    if updates:
        merge_env_file(
            ENV_PATH,
            updates,
            section_comment="# --- engine settings (console) ---",
        )
