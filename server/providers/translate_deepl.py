"""DeepL translation API — overseas machine translation."""

from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
from typing import Optional

log = logging.getLogger(__name__)


def configured() -> bool:
    return bool(os.getenv("DEEPL_API_KEY", "").strip())


def api_url() -> str:
    custom = os.getenv("DEEPL_API_URL", "").strip()
    if custom:
        return custom.rstrip("/")
    key = os.getenv("DEEPL_API_KEY", "").strip()
    if key.endswith(":fx"):
        return "https://api-free.deepl.com/v2/translate"
    return "https://api.deepl.com/v2/translate"


def translate(text: str, draft_zh: Optional[str] = None) -> str:
    text = text.strip()
    if not text:
        return ""
    if not configured():
        raise RuntimeError("DeepL not configured")

    payload: dict = {
        "text": [text],
        "source_lang": "EN",
        "target_lang": "ZH",
    }
    if draft_zh and draft_zh.strip():
        payload["context"] = f"Draft: {draft_zh.strip()}"

    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        api_url(),
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"DeepL-Auth-Key {os.environ['DEEPL_API_KEY'].strip()}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        log.error("deepl http %s: %s", exc.code, detail[:500])
        raise RuntimeError(f"DeepL HTTP {exc.code}") from exc
    except Exception as exc:
        log.exception("deepl failed")
        raise RuntimeError(f"DeepL error: {exc}") from exc

    try:
        return data["translations"][0]["text"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"DeepL bad response: {data}") from exc
