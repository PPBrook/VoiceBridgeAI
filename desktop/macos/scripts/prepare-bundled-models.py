#!/usr/bin/env python3
"""Download Whisper tiny.en + Argos en→zh into VOICEBRIDGE_MODELS_DIR for local .app bundle."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def main() -> None:
    models = Path(os.environ.get("VOICEBRIDGE_MODELS_DIR", "")).expanduser()
    if not models:
        print("VOICEBRIDGE_MODELS_DIR is required", file=sys.stderr)
        sys.exit(1)
    models.mkdir(parents=True, exist_ok=True)

    pkg = models / "argos" / "packages"
    pkg.mkdir(parents=True, exist_ok=True)

    import argostranslate.settings as argos_settings

    argos_settings.package_data_dir = str(pkg)

    from core.local_models_argos import download_argos
    from core.local_models_whisper import download_whisper

    print("Downloading Whisper tiny.en …")
    download_whisper("tiny.en")
    print("Downloading Argos en→zh …")
    download_argos()
    print(f"Bundled models ready: {models}")


if __name__ == "__main__":
    main()
