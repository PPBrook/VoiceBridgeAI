"""OpenAI LLM (OpenAI-compatible) — overseas translation / polish."""

from __future__ import annotations

import os
from typing import Optional

from llm_compat import chat_translate


def configured() -> bool:
    return bool(os.getenv("OPENAI_API_KEY", "").strip())


def base_url() -> str:
    return os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").strip().rstrip("/")


def model_name() -> str:
    return os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip() or "gpt-4o-mini"


def translate(text: str, draft_zh: Optional[str] = None, *, polish: bool = True) -> str:
    return chat_translate(
        api_key=os.getenv("OPENAI_API_KEY", ""),
        base_url=base_url(),
        model=model_name(),
        text=text,
        draft_zh=draft_zh,
        polish=polish,
    )
