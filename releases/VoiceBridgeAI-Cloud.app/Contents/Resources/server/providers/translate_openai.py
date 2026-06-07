"""OpenAI LLM (OpenAI-compatible) — overseas translation / polish."""

from __future__ import annotations

from typing import Optional

from providers.llm_openai_compat import OpenAICompatConfig, OpenAICompatProvider

_provider = OpenAICompatProvider(
    OpenAICompatConfig(
        api_key_env="OPENAI_API_KEY",
        base_url_env="OPENAI_BASE_URL",
        base_url_default="https://api.openai.com/v1",
        model_env="OPENAI_MODEL",
        model_default="gpt-4o-mini",
    )
)

configured = _provider.configured
base_url = _provider.base_url
model_name = _provider.model_name


def translate(text: str, draft_zh: Optional[str] = None, *, polish: bool = True) -> str:
    return _provider.translate(text, draft_zh, polish=polish)
