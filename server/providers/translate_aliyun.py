"""Aliyun DashScope LLM (OpenAI-compatible) — draft and final translation."""

from __future__ import annotations

import os
from typing import Optional

from core.llm_compat import chat_translate


def configured() -> bool:
    return bool(os.getenv("ALIYUN_AI_API_KEY", "").strip())


def base_url() -> str:
    default = "https://dashscope.aliyuncs.com/compatible-mode/v1"
    return os.getenv("ALIYUN_AI_BASE_URL", default).strip().rstrip("/")


def model_name() -> str:
    return os.getenv("ALIYUN_AI_MODEL", "qwen-turbo").strip() or "qwen-turbo"


def translate(text: str, draft_zh: Optional[str] = None, *, polish: bool = True) -> str:
    return chat_translate(
        api_key=os.getenv("ALIYUN_AI_API_KEY", ""),
        base_url=base_url(),
        model=model_name(),
        text=text,
        draft_zh=draft_zh,
        polish=polish,
    )
