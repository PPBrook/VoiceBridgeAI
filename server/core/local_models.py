"""Optional on-demand local models (Whisper, Argos) — not bundled in slim app builds."""

from __future__ import annotations

import logging
import os
import shutil
from pathlib import Path
from typing import Any

from config.app_paths import data_dir

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


def _env_flag(name: str, *, default: bool = True) -> bool:
    raw = os.getenv(name, "1" if default else "0").strip().lower()
    return raw not in ("0", "false", "no", "off")


def is_whisper_enabled() -> bool:
    return _env_flag("LOCAL_WHISPER_ENABLED", default=True)


def is_argos_enabled() -> bool:
    return _env_flag("LOCAL_ARGOS_ENABLED", default=True)


def set_whisper_enabled(enabled: bool) -> None:
    os.environ["LOCAL_WHISPER_ENABLED"] = "1" if enabled else "0"
    if not enabled:
        try:
            from providers.whisper_asr import unload_model

            unload_model()
        except Exception:
            pass


def set_argos_enabled(enabled: bool) -> None:
    os.environ["LOCAL_ARGOS_ENABLED"] = "1" if enabled else "0"


def models_root() -> Path:
    raw = os.getenv("VOICEBRIDGE_MODELS_DIR", "").strip()
    if raw:
        root = Path(raw).expanduser()
    else:
        root = data_dir() / "models"
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


def _all_models_roots() -> list[Path]:
    roots: list[Path] = []
    for candidate in (
        models_root(),
        Path.home() / "Library/Application Support/VoiceBridgeAI/models",
    ):
        key = str(candidate.resolve()) if candidate.exists() else str(candidate)
        if key not in {str(r.resolve()) if r.exists() else str(r) for r in roots}:
            roots.append(candidate)
    return roots


def _whisper_marker(model: str | None = None) -> Path:
    name = model or whisper_model_name()
    return models_root() / "whisper" / f".installed-{name}"


def _whisper_marker_exists(model: str | None = None) -> bool:
    name = model or whisper_model_name()
    for root in _all_models_roots():
        if (root / "whisper" / f".installed-{name}").is_file():
            return True
    return False


def is_whisper_installed(model: str | None = None) -> bool:
    if _whisper_marker_exists(model):
        return True
    if _legacy_whisper_cached(model):
        return True
    try:
        from providers.whisper_asr import _model, current_model_name

        if _model is not None and (model is None or model == current_model_name()):
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
    if _argos_marker_exists():
        return True
    if optional_local_models_enabled():
        return False
    try:
        from providers.translate_argos import pair_installed

        return pair_installed()
    except Exception:
        return False


def _argos_marker_exists() -> bool:
    for root in _all_models_roots():
        if (root / "argos" / ".installed-en-zh").is_file():
            return True
    return False


def is_whisper_any_installed() -> bool:
    return any(is_whisper_installed(m["id"]) for m in WHISPER_CHOICES)


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
        return is_whisper_any_installed()
    if model_id == "argos":
        return is_argos_installed()
    return False


def is_model_enabled(model_id: str) -> bool:
    if model_id == "whisper":
        return is_whisper_enabled()
    if model_id == "argos":
        return is_argos_enabled()
    return False


def is_model_available(model_id: str) -> bool:
    """Installed and user-enabled (shown in engine dropdown)."""
    return is_model_enabled(model_id) and is_installed(model_id)


def switch_whisper_model(model: str) -> str:
    valid = {item["id"] for item in WHISPER_CHOICES}
    if model not in valid:
        raise ValueError(f"unknown whisper model: {model}")
    if not is_whisper_installed(model):
        raise RuntimeError(f"Whisper {model} 未安装，请先下载")
    os.environ["WHISPER_MODEL"] = model
    from config.env_persist import persist_local_model_settings

    persist_local_model_settings({"whisperModel": model})
    from providers.whisper_asr import unload_model

    unload_model()
    log.info("Active Whisper model switched to %s", model)
    return model


def apply_local_model_settings(payload: dict[str, Any]) -> None:
    from config.env_persist import persist_local_model_settings

    persist_payload: dict[str, Any] = {}
    if "whisperEnabled" in payload:
        enabled = bool(payload["whisperEnabled"])
        set_whisper_enabled(enabled)
        persist_payload["whisperEnabled"] = enabled
    if "argosEnabled" in payload:
        enabled = bool(payload["argosEnabled"])
        set_argos_enabled(enabled)
        persist_payload["argosEnabled"] = enabled

    action = (payload.get("action") or "").strip().lower()
    whisper_model = (payload.get("whisperModel") or "").strip()
    if action == "switch" and whisper_model:
        switch_whisper_model(whisper_model)
    if persist_payload:
        persist_local_model_settings(persist_payload)


def download(model_id: str, *, whisper_model: str | None = None) -> str:
    if model_id == "whisper":
        return download_whisper(whisper_model)
    if model_id == "argos":
        download_argos()
        return "argos"
    raise ValueError(f"unknown local model: {model_id}")


def _remove_whisper_markers(model: str) -> None:
    for root in _all_models_roots():
        marker = root / "whisper" / f".installed-{model}"
        if marker.is_file():
            marker.unlink(missing_ok=True)


def _remove_whisper_hf_cache(model: str) -> None:
    configure_model_cache_env()
    slug = _whisper_hf_slug(model)
    for hub in _hf_hub_search_dirs():
        if not hub.is_dir():
            continue
        for path in list(hub.glob(f"{slug}*")):
            if path.is_dir():
                shutil.rmtree(path, ignore_errors=True)
            elif path.is_file():
                path.unlink(missing_ok=True)


def uninstall_whisper(model: str | None = None) -> str:
    name = (model or whisper_model_name()).strip()
    valid = {item["id"] for item in WHISPER_CHOICES}
    if name not in valid:
        raise ValueError(f"unknown whisper model: {name}")
    if not is_whisper_installed(name):
        raise RuntimeError(f"Whisper {name} 未安装")

    active = whisper_model_name()
    if name == active:
        from providers.whisper_asr import unload_model

        unload_model()

    _remove_whisper_markers(name)
    _remove_whisper_hf_cache(name)

    if name == active:
        remaining = [
            m["id"] for m in WHISPER_CHOICES if m["id"] != name and is_whisper_installed(m["id"])
        ]
        if remaining:
            switch_whisper_model(remaining[0])
        else:
            from providers.whisper_asr import unload_model

            unload_model()

    log.info("Whisper %s uninstalled", name)
    return name


def uninstall_argos() -> None:
    import argostranslate.package as argos_package
    import argostranslate.translate as argos_translate

    from providers.translate_argos import FROM_CODE, TO_CODE, reset_ready

    reset_ready()

    for root in _all_models_roots():
        marker = root / "argos" / ".installed-en-zh"
        if marker.is_file():
            marker.unlink(missing_ok=True)

    for pkg in list(argos_package.get_installed_packages()):
        if pkg.from_code == FROM_CODE and pkg.to_code == TO_CODE:
            argos_package.uninstall(pkg)

    try:
        import argostranslate.settings as argos_settings

        pkg_dir = Path(argos_settings.package_data_dir)
        if pkg_dir.is_dir():
            shutil.rmtree(pkg_dir)
            pkg_dir.mkdir(parents=True, exist_ok=True)
    except Exception as exc:
        log.warning("Argos package cleanup: %s", exc)

    argos_translate.get_installed_languages.cache_clear()
    log.info("Argos en→zh uninstalled")


def uninstall(model_id: str, *, whisper_model: str | None = None) -> str:
    if model_id == "whisper":
        return uninstall_whisper(whisper_model)
    if model_id == "argos":
        uninstall_argos()
        return "argos"
    raise ValueError(f"unknown local model: {model_id}")


def get_status() -> dict[str, Any]:
    whisper = whisper_model_name()
    models: list[dict[str, Any]] = []
    for item in LOCAL_MODELS:
        entry: dict[str, Any] = {
            **item,
            "installed": is_installed(item["id"]),
            "enabled": is_model_enabled(item["id"]),
            "available": is_model_available(item["id"]),
        }
        if item["id"] == "whisper":
            entry["installedModels"] = [
                m["id"] for m in WHISPER_CHOICES if is_whisper_installed(m["id"])
            ]
            entry["activeModel"] = whisper
            # 当前规格是否已安装（供 UI 判断，避免仅依赖 installedModels 列表）
            entry["activeInstalled"] = is_whisper_installed(whisper)
        models.append(entry)
    return {
        "optionalLocalModels": optional_local_models_enabled(),
        "modelsDir": str(models_root()),
        "whisperModel": whisper,
        "whisperChoices": list(WHISPER_CHOICES),
        "whisperEnabled": is_whisper_enabled(),
        "argosEnabled": is_argos_enabled(),
        "localModels": models,
    }
