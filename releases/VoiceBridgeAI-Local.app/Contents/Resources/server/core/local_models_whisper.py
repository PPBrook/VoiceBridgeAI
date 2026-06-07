"""Whisper local model install, download, and uninstall."""

from __future__ import annotations

import logging
import os
import shutil
from typing import Callable

from core.local_model_messages import model_label, progress_text
from core.local_models_catalog import WHISPER_CHOICES, whisper_model_name
from core.local_models_paths import (
    all_models_roots,
    configure_model_cache_env,
    hf_hub_search_dirs,
    models_root,
    whisper_hf_slug,
    whisper_marker,
    whisper_marker_exists,
)

log = logging.getLogger(__name__)

ProgressCallback = Callable[[float, str], None]


def _legacy_whisper_cached(model: str | None = None) -> bool:
    name = model or whisper_model_name()
    slug = whisper_hf_slug(name)
    for hub in hf_hub_search_dirs():
        if not hub.is_dir():
            continue
        if list(hub.glob(f"{slug}*")) or list(hub.glob(f"**/{slug}")):
            return True
    return False


def is_whisper_installed(model: str | None = None) -> bool:
    if whisper_marker_exists(model):
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
    marker = whisper_marker(model or whisper_model_name())
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()


def _whisper_hf_repo(model: str) -> str:
    return f"Systran/faster-whisper-{model}"


def download_whisper(
    model: str | None = None,
    *,
    on_progress: ProgressCallback | None = None,
) -> str:
    configure_model_cache_env()
    name = model or whisper_model_name()
    label = model_label("whisper", name)
    log.info("Downloading Whisper model %s …", name)

    def report(progress: float, step: str, *, ratio: float | None = None) -> None:
        if on_progress:
            on_progress(progress, progress_text(label, step, ratio=ratio))

    report(0.03, "准备下载")

    from faster_whisper import WhisperModel
    from huggingface_hub import snapshot_download
    from huggingface_hub.utils import tqdm as hf_tqdm

    repo_id = _whisper_hf_repo(name)
    tqdm_class: type = hf_tqdm
    if on_progress:

        class ProgressTqdm(hf_tqdm):
            def update(self, n=1):
                result = super().update(n)
                total = self.total or 0
                if total > 0:
                    ratio = self.n / total
                    on_progress(
                        0.08 + 0.82 * ratio,
                        progress_text(label, "正在下载", ratio=ratio),
                    )
                return result

        tqdm_class = ProgressTqdm

    report(0.08, "正在下载")
    snapshot_download(repo_id=repo_id, tqdm_class=tqdm_class)

    report(0.92, "正在校验")
    WhisperModel(name, device="cpu", compute_type="int8")
    mark_whisper_installed(name)
    os.environ["WHISPER_MODEL"] = name
    report(1.0, "完成")
    log.info("Whisper %s ready", name)
    return name


def is_whisper_any_installed() -> bool:
    return any(is_whisper_installed(m["id"]) for m in WHISPER_CHOICES)


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


def _remove_whisper_markers(model: str) -> None:
    for root in all_models_roots():
        marker = root / "whisper" / f".installed-{model}"
        if marker.is_file():
            marker.unlink(missing_ok=True)


def _remove_whisper_hf_cache(model: str) -> None:
    configure_model_cache_env()
    slug = whisper_hf_slug(model)
    for hub in hf_hub_search_dirs():
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
