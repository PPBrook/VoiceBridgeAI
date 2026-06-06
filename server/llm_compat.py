"""Shared OpenAI-compatible chat completions client for LLM translation."""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import Optional

log = logging.getLogger(__name__)

POLISH_SYSTEM = (
    "你是专业同声传译员。将用户给出的英文译为流畅自然的中文。"
    "只输出中文译文，不要解释、不要引号、不要前缀。"
)
DRAFT_SYSTEM = "将英文译为中文，只输出译文，不要解释。"


def chat_translate(
    *,
    api_key: str,
    base_url: str,
    model: str,
    text: str,
    draft_zh: Optional[str] = None,
    polish: bool = True,
    timeout: int = 45,
) -> str:
    text = text.strip()
    if not text:
        return ""
    if not api_key.strip():
        raise RuntimeError("LLM API key not configured")

    user_content = f"英文：{text}"
    if polish and draft_zh and draft_zh.strip():
        user_content += (
            f"\n机器翻译草稿：{draft_zh.strip()}\n请润色为更自然的中文，只输出译文。"
        )

    body = json.dumps(
        {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": POLISH_SYSTEM if polish else DRAFT_SYSTEM,
                },
                {"role": "user", "content": user_content},
            ],
            "temperature": 0.3,
            "max_tokens": 512,
        }
    ).encode("utf-8")

    url = base_url.rstrip("/") + "/chat/completions"
    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key.strip()}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        log.error("llm http %s: %s", exc.code, detail[:500])
        raise RuntimeError(f"LLM HTTP {exc.code}") from exc
    except Exception as exc:
        log.exception("llm request failed")
        raise RuntimeError(f"LLM error: {exc}") from exc

    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"LLM bad response: {data}") from exc
    return (content or "").strip()
