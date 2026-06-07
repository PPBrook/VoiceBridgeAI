"""Local model storage paths and markers."""

from __future__ import annotations

import os
from pathlib import Path

from config.app_paths import data_dir


def models_root() -> Path:
    raw = os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip()
    if raw:
        root = Path(raw).expanduser()
    else:
        root = data_dir() / "models"
    root.mkdir(parents=True, exist_ok=True)
    return root


def configure_model_cache_env() -> None:
    from core.local_models_catalog import optional_local_models_enabled

    if not optional_local_models_enabled() and not os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip():
        return
    root = models_root()
    hf = root / "hf"
    hub = hf / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("HF_HOME", str(hf))
    os.environ.setdefault("HUGGINGFACE_HUB_CACHE", str(hub))


def whisper_hf_slug(model: str) -> str:
    return f"models--Systran--faster-whisper-{model.replace('.', '-')}"


def hf_hub_search_dirs() -> list[Path]:
    dirs: list[Path] = []
    for env_key in ("HUGGINGFACE_HUB_CACHE", "HF_HOME"):
        raw = os.getenv(env_key, "").strip()
        if raw:
            p = Path(raw).expanduser()
            dirs.append(p / "hub" if p.name != "hub" else p)
    dirs.append(Path.home() / ".cache" / "huggingface" / "hub")
    dirs.append(models_root() / "hf" / "hub")
    seen: set[str] = set()
    out: list[Path] = []
    for d in dirs:
        key = str(d.resolve()) if d.exists() else str(d)
        if key not in seen:
            seen.add(key)
            out.append(d)
    return out


def all_models_roots() -> list[Path]:
    roots: list[Path] = []
    for candidate in (
        models_root(),
        Path.home() / "Library/Application Support/VoiceBridgeAI/models",
    ):
        key = str(candidate.resolve()) if candidate.exists() else str(candidate)
        if key not in {str(r.resolve()) if r.exists() else str(r) for r in roots}:
            roots.append(candidate)
    return roots


def whisper_marker(model: str | None = None) -> Path:
    from core.local_models_catalog import whisper_model_name

    name = model or whisper_model_name()
    return models_root() / "whisper" / f".installed-{name}"


def whisper_marker_exists(model: str | None = None) -> bool:
    from core.local_models_catalog import whisper_model_name

    name = model or whisper_model_name()
    for root in all_models_roots():
        if (root / "whisper" / f".installed-{name}").is_file():
            return True
    return False


def argos_marker_exists() -> bool:
    for root in all_models_roots():
        if (root / "argos" / ".installed-en-zh").is_file():
            return True
    return False
