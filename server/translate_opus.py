"""Offline English → Chinese via Helsinki-NLP OPUS-MT."""

from __future__ import annotations

import logging
import os
from typing import Optional

log = logging.getLogger(__name__)

MODEL_NAME = os.getenv("OPUS_MT_MODEL", "Helsinki-NLP/opus-mt-en-zh")
_tokenizer = None
_model = None


def load_model() -> None:
    global _tokenizer, _model
    if _model is not None:
        return
    from transformers import MarianMTModel, MarianTokenizer

    log.info("Loading OPUS-MT %s (cpu) …", MODEL_NAME)
    _tokenizer = MarianTokenizer.from_pretrained(MODEL_NAME)
    _model = MarianMTModel.from_pretrained(MODEL_NAME)
    _model.eval()
    log.info("OPUS-MT ready")


def translate(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    import torch

    load_model()
    assert _tokenizer is not None and _model is not None
    batch = _tokenizer([text], return_tensors="pt", padding=True, truncation=True)
    with torch.no_grad():
        out = _model.generate(**batch, max_length=512)
    return _tokenizer.decode(out[0], skip_special_tokens=True).strip()
