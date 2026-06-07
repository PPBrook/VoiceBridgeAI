"""Human-readable HTTP error messages for provider tests."""

from __future__ import annotations

import json
import re


def _extract_message(body: str) -> str:
    text = body.strip()
    if not text:
        return ""
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return re.sub(r"\s+", " ", text).strip()

    if isinstance(data, dict):
        err = data.get("error")
        if isinstance(err, dict):
            for key in ("message", "msg", "detail"):
                if err.get(key):
                    return str(err[key]).strip()
        for key in ("message", "msg", "detail", "error"):
            if data.get(key) and not isinstance(data[key], (dict, list)):
                return str(data[key]).strip()
    return re.sub(r"\s+", " ", text).strip()


def _redact_secrets(text: str) -> str:
    text = re.sub(r"sk-[A-Za-z0-9._-]+", "sk-…", text)
    text = re.sub(r"AKID[A-Za-z0-9]+", "AKID…", text)
    return text


def format_http_error(
    label: str,
    code: int,
    body: str,
    *,
    max_len: int = 140,
) -> str:
    msg = _redact_secrets(_extract_message(body))
    if not msg:
        msg = f"HTTP {code}"
    msg = re.sub(r"\s+", " ", msg).strip()
    if len(msg) > max_len:
        msg = msg[: max_len - 1].rstrip() + "…"
    return f"{label} HTTP {code}：{msg}"
