"""Argos local translation model install, download, and uninstall."""

from __future__ import annotations

import logging
import shutil
from pathlib import Path
from typing import Callable

from core.local_model_messages import model_label, progress_text
from core.local_models_catalog import optional_local_models_enabled
from core.local_models_paths import all_models_roots, models_root

log = logging.getLogger(__name__)

ProgressCallback = Callable[[float, str], None]


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
    for root in all_models_roots():
        if (root / "argos" / ".installed-en-zh").is_file():
            return True
    return False


def download_argos(*, on_progress: ProgressCallback | None = None) -> None:
    import argostranslate.package as argos_package

    from providers.translate_argos import FROM_CODE, TO_CODE

    label = model_label("argos")

    def report(progress: float, step: str) -> None:
        if on_progress:
            on_progress(progress, progress_text(label, step))

    log.info("Downloading Argos %s→%s pack …", FROM_CODE, TO_CODE)
    report(0.05, "更新索引")
    argos_package.update_package_index()
    report(0.12, "查找语言包")
    available = argos_package.get_available_packages()
    pkg = next(
        (p for p in available if p.from_code == FROM_CODE and p.to_code == TO_CODE),
        None,
    )
    if pkg is None:
        raise RuntimeError("Argos en→zh package not found in index")
    report(0.2, "正在下载")
    path = pkg.download()
    report(0.72, "正在安装")
    argos_package.install_from_path(path)
    marker = models_root() / "argos" / ".installed-en-zh"
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.touch()
    report(1.0, "完成")
    log.info("Argos en→zh pack installed")


def uninstall_argos() -> None:
    import argostranslate.package as argos_package
    import argostranslate.translate as argos_translate

    from providers.translate_argos import FROM_CODE, TO_CODE, reset_ready

    reset_ready()

    for root in all_models_roots():
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
