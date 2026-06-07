"""Baidu general translation API — domestic machine translation."""

from __future__ import annotations

import hashlib
import json
import logging
import os
import random
import urllib.parse
import urllib.request

log = logging.getLogger(__name__)


def configured() -> bool:
    return bool(
        os.getenv("BAIDU_APP_ID", "").strip()
        and os.getenv("BAIDU_SECRET_KEY", "").strip()
    )


def translate(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    if not configured():
        raise RuntimeError("Baidu translate not configured")

    app_id = os.environ["BAIDU_APP_ID"].strip()
    secret = os.environ["BAIDU_SECRET_KEY"].strip()
    salt = str(random.randint(32768, 65536))
    sign = hashlib.md5(f"{app_id}{text}{salt}{secret}".encode()).hexdigest()

    params = urllib.parse.urlencode(
        {
            "q": text,
            "from": "en",
            "to": "zh",
            "appid": app_id,
            "salt": salt,
            "sign": sign,
        }
    )
    url = f"https://fanyi-api.baidu.com/api/trans/vip/translate?{params}"
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception as exc:
        log.exception("baidu translate failed")
        raise RuntimeError(f"Baidu translate error: {exc}") from exc

    if data.get("error_code"):
        raise RuntimeError(
            f"Baidu translate error {data.get('error_code')}: {data.get('error_msg')}"
        )
    try:
        return data["trans_result"][0]["dst"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"Baidu bad response: {data}") from exc
