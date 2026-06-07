"""Optional on-demand local models (Whisper, Argos) — not bundled in slim app builds."""

from __future__ import annotations

import logging
import os
from pathlib import Path
from typing import Any

log = logging.getLogger(__name__)

LOCAL_MODELS = (
    {
        "id": "whisper",
        "label": "Whisper 语音识别",
        "description": "本地离线 ASR（faster-whisper，CPU int8）",
        "sizeHint": "~75 MB（tiny.en）",
        "layer": "asr",
    },
    {
        "id": "argos",
        "label": "Argos 英译中",
        "description": "离线句中/句末翻译语言包（en→zh）",
        "sizeHint": "~100 MB",
        "layer": "partial",
    },
)

WHISPER_CHOICES = (
    {"id": "tiny.en", "label": "tiny.en · 推荐（体积小）", "sizeHint": "~75 MB"},
    {"id": "base.en", "label": "base.en · 更准确", "sizeHint": "~150 MB"},
)


def optional_local_models_enabled() -> bool:
    """Default on (desktop-first main). Set VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=0 on legacy/web-only."""
    raw = os.getenv("VOICEBRIDGE_OPTIONAL_LOCAL_MODELS", "1").strip().lower()
    return raw not in ("0", "false", "no", "off")


def models_root() -> Path:
    raw = os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip()
    if raw:
        root = Path(raw).expanduser()
    else:
        root = Path.home() / "Library" / "Application Support" / "VoiceBridgeAI" / "models"
    root.mkdir(parents=True, exist_ok=True)
    return root


def configure_model_cache_env() -> None:
    """Use dedicated model dir when optional mode or VOICEBRIDGE_MODELS_DIR is set."""
    if not optional_local_models_enabled() and not os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip():
        return
    root = models_root()
    hf = root / "hf"
    hub = hf / "hub"
    hub.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("HF_HOME", str(hf))
    os.environ.setdefault("HUGGINGFACE_HUB_CACHE", str(hub))


def whisper_model_name() -> str:
    return os.getenv("WHISPER_MODEL", "tiny.en").strip() or "tiny.en"


def _whisper_hf_slug(model: str) -> str:
    return f"models--Systran--faster-whisper-{model.replace('.', '-')}"


def _hf_hub_search_dirs() -> list[Path]:
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


def _legacy_whisper_cached(model: str | None = None) -> bool:
    name = model or whisper_model_name()
    slug = _whisper_hf_slug(name)
    for hub in _hf_hub_search_dirs():
        if not hub.is_dir():
            continue
        if list(hub.glob(f"{slug}*")) or list(hub.glob(f"**/{slug}")):
            return True
    return False


def _whisper_marker(model: str | None = None) -> Path:
    name = model or whisper_model_name()
    return models_root() / "whisper" / f".installed-{name}"


def is_whisper_installed(model: str | None = None) -> bool:
    if _whisper_marker(model).exists():
        return True
    if _legacy_whisper_cached(model):
        return True
    try:
        from providers.whisper_asr import _model

        if _model is not None:
            return True
    except Exception:
        pass
    return False


def mark_whisper_installed(model: str | None = None) -> None:
    marker = _whisper_marker(model)
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()


def download_whisper(model: str | None = None) -> str:
    configure_model_cache_env()
    name = model or whisper_model_name()
    log.info("Downloading Whisper model %s …", name)
    from faster_whisper import WhisperModel

    WhisperModel(name, device="cpu", compute_type="int8")
    mark_whisper_installed(name)
    os.environ["WHISPER_MODEL"] = name
    log.info("Whisper %s ready", name)
    return name


def is_argos_installed() -> bool:
    try:
        from providers.translate_argos import pair_installed

        return pair_installed()
    except Exception:
        return False


def download_argos() -> None:
    import argostranslate.package as argos_package

    from providers.translate_argos import FROM_CODE, TO_CODE

    log.info("Downloading Argos %s→%s pack …", FROM_CODE, TO_CODE)
    argos_package.update_package_index()
    available = argos_package.get_available_packages()
    pkg = next(
        (p for p in available if p.from_code == FROM_CODE and p.to_code == TO_CODE),
        None,
    )
    if pkg is None:
        raise RuntimeError("Argos en→zh package not found in index")
    argos_package.install_from_path(pkg.download())
    marker = models_root() / "argos" / ".installed-en-zh"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()
    log.info("Argos en→zh pack installed")


def is_installed(model_id: str) -> bool:
    if model_id == "whisper":
        return is_whisper_installed()
    if model_id == "argos":
        return is_argos_installed()
    return False


def download(model_id: str, *, whisper_model: str | None = None) -> str:
    if model_id == "whisper":
        return download_whisper(whisper_model)
    if model_id == "argos":
        download_argos()
        return "argos"
    raise ValueError(f"unknown local model: {model_id}")


def get_status() -> dict[str, Any]:
    whisper = whisper_model_name()
    return {
        "optionalLocalModels": optional_local_models_enabled(),
        "modelsDir": str(models_root()),
        "whisperModel": whisper,
        "whisperChoices": list(WHISPER_CHOICES),
        "localModels": [
            {
                **item,
                "installed": is_installed(item["id"]),
            }
            for item in LOCAL_MODELS
        ],
    }
