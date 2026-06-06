"""Paths for dev (repo) vs bundled (.app) layouts."""

from __future__ import annotations

import os
from pathlib import Path

SERVER_DIR = Path(__file__).resolve().parent


def _dev_repo_root() -> Path | None:
    direct = SERVER_DIR.parent
    if (direct / "run.sh").is_file():
        return direct
    nested = direct.parent
    if (nested / "run.sh").is_file():
        return nested
    return None


def data_dir() -> Path:
    raw = os.getenv("VOICEBRIDGE_DATA_DIR", "").strip()
    if raw:
        root = Path(raw).expanduser()
    else:
        dev = _dev_repo_root()
        if dev is not None:
            root = dev
        else:
            root = Path.home() / "Library" / "Application Support" / "VoiceBridgeAI"
    root.mkdir(parents=True, exist_ok=True)
    return root


def env_file_path() -> Path:
    return data_dir() / ".env"


def repo_root() -> Path:
    dev = _dev_repo_root()
    if dev is not None:
        return dev
    return SERVER_DIR.parent


def docs_dir() -> Path | None:
    docs = repo_root() / "docs"
    return docs if docs.is_dir() else None
