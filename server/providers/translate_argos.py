"""Offline English → Chinese via Argos Translate."""

from __future__ import annotations

import logging

log = logging.getLogger(__name__)

_ready = False
FROM_CODE = "en"
TO_CODE = "zh"


def pair_installed() -> bool:
    import argostranslate.translate as argos_translate

    from_lang = next(
        (l for l in argos_translate.get_installed_languages() if l.code == FROM_CODE),
        None,
    )
    if from_lang is None:
        return False
    to_lang = next(
        (l for l in argos_translate.get_installed_languages() if l.code == TO_CODE),
        None,
    )
    if to_lang is None:
        return False
    return from_lang.get_translation(to_lang) is not None


def _install_argos_pack() -> None:
    import argostranslate.package as argos_package

    log.info("Argos: downloading en→zh language pack (one-time) …")
    argos_package.update_package_index()
    available = argos_package.get_available_packages()
    pkg = next(
        (p for p in available if p.from_code == FROM_CODE and p.to_code == TO_CODE),
        None,
    )
    if pkg is None:
        raise RuntimeError("Argos en→zh package not found in index")
    argos_package.install_from_path(pkg.download())
    log.info("Argos en→zh pack installed")


def load_model() -> None:
    global _ready
    if _ready:
        return
    from core.local_models import optional_local_models_enabled

    if not pair_installed():
        if optional_local_models_enabled():
            raise RuntimeError(
                "Argos 英译中语言包未安装。请在设置中下载本地模型，或改用云端翻译。"
            )
        _install_argos_pack()
    _ready = True
    log.info("Argos translate ready")


def reset_ready() -> None:
    global _ready
    _ready = False


def translate(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    load_model()
    import argostranslate.translate as argos_translate

    return (argos_translate.translate(text, FROM_CODE, TO_CODE) or "").strip()
