"""Paths for dev (repo) vs bundled (.app) layouts."""

from __future__ import annotations

import os
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parent.parent


def _dev_repo_root() -> Path | None:
    for base in (SERVER_DIR.parent, SERVER_DIR.parent.parent):
        if (base / "run.sh").is_file() or (base / "run.ps1").is_file():
            return base
    return None


def _default_data_root() -> Path:
    if os.name == "nt":
        appdata = os.getenv("APPDATA", "").strip()
        if appdata:
            return Path(appdata) / "VoiceBridgeAI"
        return Path.home() / "AppData" / "Roaming" / "VoiceBridgeAI"
    return Path.home() / "Library" / "Application Support" / "VoiceBridgeAI"


def data_dir() -> Path:
    raw = os.getenv("VOICEBRIDGE_DATA_DIR", "").strip()
    if raw:
        root = Path(raw).expanduser()
    elif (dev := _dev_repo_root()) is not None:
        root = dev
    else:
        root = _default_data_root()
    root.mkdir(parents=True, exist_ok=True)
    return root


def env_file_path() -> Path:
    return data_dir() / ".env"
