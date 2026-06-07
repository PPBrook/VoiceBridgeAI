#!/usr/bin/env python3
"""Download Whisper tiny.en + Argos en→zh into VOICEBRIDGE_MODELS_DIR for local Windows bundle."""

from __future__ import annotations

import os
import sys
from pathlib import Path

# Script lives at desktop/windows/scripts/ — server package is at repo/server/.
REPO_ROOT = Path(__file__).resolve().parents[3]
SERVER_ROOT = REPO_ROOT / "server"
if not SERVER_ROOT.is_dir():
    print(f"server directory not found: {SERVER_ROOT}", file=sys.stderr)
    sys.exit(1)
sys.path.insert(0, str(SERVER_ROOT))


def main() -> None:
    models = Path(os.environ.get("VOICEBRIDGE_MODELS_DIR", "")).expanduser()
    if not models:
        print("VOICEBRIDGE_MODELS_DIR is required", file=sys.stderr)
        sys.exit(1)
    models.mkdir(parents=True, exist_ok=True)

    os.environ.setdefault("LOCAL_WHISPER_ENABLED", "1")
    os.environ.setdefault("LOCAL_ARGOS_ENABLED", "1")
    os.environ.setdefault("VOICEBRIDGE_OPTIONAL_LOCAL_MODELS", "0")

    pkg = models / "argos" / "packages"
    pkg.mkdir(parents=True, exist_ok=True)

    import argostranslate.settings as argos_settings

    argos_settings.package_data_dir = str(pkg)

    from core.local_models_paths import configure_model_cache_env
    from core.local_models_argos import download_argos
    from core.local_models_whisper import download_whisper

    configure_model_cache_env()

    print("Downloading Whisper tiny.en …")
    download_whisper("tiny.en")
    print("Downloading Argos en→zh …")
    download_argos()
    print(f"Bundled models ready: {models}")


if __name__ == "__main__":
    main()
