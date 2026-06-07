"""Cloud settings panel UI preferences (hidden provider cards)."""

from __future__ import annotations

import json
from typing import Any

from config.app_paths import data_dir

_PREFS_FILE = "cloud-ui.json"

# Card id → (layer, provider_id) test targets shown in the macOS cloud panel.
CARD_TEST_TARGETS: dict[str, tuple[tuple[str, str], ...]] = {
    "tencent": (("asr", "tencent"), ("partial", "tmt"), ("final", "tmt")),
    "qiniu": (("partial", "qiniu"), ("final", "qiniu")),
    "aliyun": (("partial", "aliyun"), ("final", "aliyun")),
    "baidu": (("partial", "baidu"), ("final", "baidu")),
    "deepseek": (("partial", "deepseek"), ("final", "deepseek")),
    "openai": (("asr", "openai"), ("partial", "openai"), ("final", "openai")),
    "deepl": (("partial", "deepl"), ("final", "deepl")),
    "google": (("partial", "google"), ("final", "google")),
}

ALL_CARD_IDS = tuple(CARD_TEST_TARGETS.keys())


def _prefs_path():
    return data_dir() / _PREFS_FILE


def _read_raw() -> dict[str, Any]:
    path = _prefs_path()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def get_hidden_providers() -> set[str]:
    raw = _read_raw().get("hiddenProviders")
    if not isinstance(raw, list):
        return set()
    return {str(item).strip() for item in raw if str(item).strip() in CARD_TEST_TARGETS}


def save_hidden_providers(card_ids: list[str]) -> list[str]:
    hidden = sorted({cid for cid in card_ids if cid in CARD_TEST_TARGETS})
    path = _prefs_path()
    path.write_text(
        json.dumps({"hiddenProviders": hidden}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return hidden


def ui_prefs_status() -> dict[str, Any]:
    hidden = sorted(get_hidden_providers())
    return {"hiddenProviders": hidden}


def is_target_hidden(layer: str, provider_id: str, hidden_cards: set[str] | None = None) -> bool:
    hidden = hidden_cards if hidden_cards is not None else get_hidden_providers()
    if not hidden:
        return False
    for card_id in hidden:
        for lay, pid in CARD_TEST_TARGETS.get(card_id, ()):
            if lay == layer and pid == provider_id:
                return True
    return False
