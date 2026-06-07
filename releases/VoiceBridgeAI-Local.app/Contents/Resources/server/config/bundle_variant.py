"""App bundle variant: cloud (API-only) vs local (prebundled offline models)."""

from __future__ import annotations

import os
from pathlib import Path


def bundle_variant() -> str:
    return os.getenv("VOICEBRIDGE_BUNDLE_VARIANT", "").strip().lower()


def local_models_feature_enabled() -> bool:
    variant = bundle_variant()
    return variant != "cloud"


def configure_bundled_runtime() -> None:
    """Point Argos package dir at bundled models when running the local .app."""
    if bundle_variant() != "local":
        return
    raw = os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip()
    if not raw:
        return
    pkg = Path(raw).expanduser() / "argos" / "packages"
    if not pkg.is_dir():
        return
    try:
        import argostranslate.settings as argos_settings

        argos_settings.package_data_dir = str(pkg)
    except Exception:
        pass
