"""Qiniu AI LLM — fluent final translation / polish."""

from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request
from typing import Optional

log = logging.getLogger(__name__)

SYSTEM_PROMPT = (
    "你是专业同声传译员。将用户给出的英文译为流畅自然的中文。"
    "只输出中文译文，不要解释、不要引号、不要前缀。"
)


def configured() -> bool:
    return bool(os.getenv("QINIU_AI_API_KEY", "").strip())


def base_url() -> str:
    return os.getenv("QINIU_AI_BASE_URL", "https://api.qnaigc.com/v1").strip().rstrip("/")


def model_name() -> str:
    return os.getenv("QINIU_AI_MODEL", "qwen-turbo").strip() or "qwen-turbo"


def translate(text: str, draft_zh: Optional[str] = None) -> str:
    text = text.strip()
    if not text:
        return ""
    if not configured():
        raise RuntimeError("Qiniu AI not configured")

    user_content = f"英文：{text}"
    if draft_zh and draft_zh.strip():
        user_content += f"\n机器翻译草稿：{draft_zh.strip()}\n请润色为更自然的中文，只输出译文。"

    body = json.dumps(
        {
            "model": model_name(),
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.3,
            "max_tokens": 512,
        }
    ).encode("utf-8")

    req = urllib.request.Request(
        f"{base_url()}/chat/completions",
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {os.environ['QINIU_AI_API_KEY'].strip()}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=45) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        log.error("qiniu llm http %s: %s", exc.code, detail[:500])
        raise RuntimeError(f"Qiniu LLM HTTP {exc.code}") from exc
    except Exception as exc:
        log.exception("qiniu llm failed")
        raise RuntimeError(f"Qiniu LLM error: {exc}") from exc

    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"Qiniu LLM bad response: {data}") from exc
    return (content or "").strip()
