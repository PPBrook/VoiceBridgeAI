"""DeepSeek LLM (OpenAI-compatible) — domestic translation / polish."""

from __future__ import annotations

import os
from typing import Optional

from core.llm_compat import chat_translate


def configured() -> bool:
    return bool(os.getenv("DEEPSEEK_API_KEY", "").strip())


def base_url() -> str:
    return os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com/v1").strip().rstrip(
        "/"
    )


def model_name() -> str:
    return os.getenv("DEEPSEEK_MODEL", "deepseek-chat").strip() or "deepseek-chat"


def translate(text: str, draft_zh: Optional[str] = None, *, polish: bool = True) -> str:
    return chat_translate(
        api_key=os.getenv("DEEPSEEK_API_KEY", ""),
        base_url=base_url(),
        model=model_name(),
        text=text,
        draft_zh=draft_zh,
        polish=polish,
    )
