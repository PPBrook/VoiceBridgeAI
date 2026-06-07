"""Shared OpenAI-compatible chat completions client for LLM translation."""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import Optional

from core.revise_context import get_polish_scene_hint

log = logging.getLogger(__name__)

POLISH_SYSTEM_BASE = (
    "你是英译中同声传译员，译文将直接显示为视频悬浮字幕。"
    "要求：流畅易读；不要擅自增删信息；"
    "人名、产品名及常见技术术语可保留英文或通用译法，全文译名保持一致。"
    "只输出最终中文，不要解释、不要引号、不要序号、不要任何前缀或后缀。"
)
DRAFT_SYSTEM_BASE = (
    "将英文译为中文，用于实时字幕速览。"
    "译文应简短自然，只输出中文，不要解释。"
)


def _append_scene_hint(base: str, scene_hint: str) -> str:
    hint = scene_hint.strip()
    if not hint:
        return base
    return f"{base}\n{hint}"


def build_polish_system(scene_hint: str | None = None) -> str:
    return _append_scene_hint(POLISH_SYSTEM_BASE, scene_hint or get_polish_scene_hint())


def build_draft_system(scene_hint: str | None = None) -> str:
    hint = (scene_hint or get_polish_scene_hint()).strip()
    if not hint:
        return DRAFT_SYSTEM_BASE
    return _append_scene_hint(DRAFT_SYSTEM_BASE, hint)


def _build_user_content(text: str, draft_zh: Optional[str], *, polish: bool) -> str:
    if polish and draft_zh and draft_zh.strip():
        return (
            f"【英文原文】\n{text}\n\n"
            f"【句中翻译草稿】\n{draft_zh.strip()}\n\n"
            "请在保持原意的前提下润色为更适合当前观看场景的字幕中文。"
            "只输出润色后的译文。"
        )
    if polish:
        return (
            f"【英文原文】\n{text}\n\n"
            "请译为适合当前观看场景的字幕中文，只输出译文。"
        )
    return f"【英文】\n{text}\n\n请译为字幕速览中文，只输出译文。"


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

    user_content = _build_user_content(text, draft_zh, polish=polish)
    system_content = build_polish_system() if polish else build_draft_system()

    body = json.dumps(
        {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": system_content,
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
        from core.http_errors import format_http_error

        raise RuntimeError(format_http_error("LLM", exc.code, detail)) from exc
    except Exception as exc:
        log.exception("llm request failed")
        raise RuntimeError(f"LLM error: {exc}") from exc

    try:
        content = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"LLM bad response: {data}") from exc
    return (content or "").strip()
