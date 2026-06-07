"""User-facing copy for local model download progress."""

from __future__ import annotations


def model_label(model_id: str, whisper_model: str | None = None) -> str:
    if model_id == "whisper":
        name = (whisper_model or "tiny.en").strip()
        return f"Whisper {name}"
    if model_id == "argos":
        return "Argos 英译中"
    return model_id


def progress_text(label: str, step: str, *, ratio: float | None = None) -> str:
    text = f"{label} · {step}"
    if ratio is not None:
        pct = max(0, min(100, int(ratio * 100)))
        if pct > 0 and pct < 100:
            return f"{text} {pct}%"
    return text


def done_text(label: str) -> str:
    return f"{label} · 下载完成"


def error_text(label: str, detail: str) -> str:
    detail = detail.strip()
    if detail:
        return f"{label} · 下载失败：{detail}"
    return f"{label} · 下载失败"
