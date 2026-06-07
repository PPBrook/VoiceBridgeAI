"""Factory for OpenAI-compatible LLM translation providers."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Optional

from core.llm_compat import chat_translate


@dataclass(frozen=True)
class OpenAICompatConfig:
    api_key_env: str
    base_url_env: str
    base_url_default: str
    model_env: str
    model_default: str


class OpenAICompatProvider:
    def __init__(self, config: OpenAICompatConfig) -> None:
        self._config = config

    def configured(self) -> bool:
        return bool(os.getenv(self._config.api_key_env, "").strip())

    def base_url(self) -> str:
        raw = os.getenv(self._config.base_url_env, self._config.base_url_default).strip()
        return raw.rstrip("/") or self._config.base_url_default.rstrip("/")

    def model_name(self) -> str:
        raw = os.getenv(self._config.model_env, self._config.model_default).strip()
        return raw or self._config.model_default

    def translate(
        self,
        text: str,
        draft_zh: Optional[str] = None,
        *,
        polish: bool = True,
    ) -> str:
        return chat_translate(
            api_key=os.getenv(self._config.api_key_env, ""),
            base_url=self.base_url(),
            model=self.model_name(),
            text=text,
            draft_zh=draft_zh,
            polish=polish,
        )
