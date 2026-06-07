"""OpenAI Whisper API — cloud speech recognition (overseas)."""

from __future__ import annotations

import io
import json
import logging
import os
import uuid
import wave

import numpy as np
import urllib.error
import urllib.request

from core.pcm import TARGET_RATE

log = logging.getLogger(__name__)


def configured() -> bool:
    return bool(os.getenv("OPENAI_API_KEY", "").strip())


def asr_model() -> str:
    return os.getenv("OPENAI_ASR_MODEL", "whisper-1").strip() or "whisper-1"


def _prepare_pcm(pcm: bytes, sample_rate: int) -> bytes:
    audio = np.frombuffer(pcm, dtype=np.int16).astype(np.float32) / 32768.0
    if sample_rate != TARGET_RATE and sample_rate:
        n = int(len(audio) * TARGET_RATE / sample_rate)
        if n < 1:
            return b""
        idx = np.linspace(0, len(audio) - 1, n)
        audio = np.interp(idx, np.arange(len(audio)), audio).astype(np.float32)
    pcm16 = (audio * 32767.0).clip(-32768, 32767).astype(np.int16).tobytes()
    return pcm16


def _pcm_to_wav(pcm: bytes, sample_rate: int) -> bytes:
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm)
    return buf.getvalue()


def _multipart_body(wav: bytes, model: str) -> tuple[bytes, str]:
    boundary = f"----VoiceBridge{uuid.uuid4().hex}"
    lines: list[bytes] = []

    def add_field(name: str, value: str) -> None:
        lines.append(f"--{boundary}\r\n".encode())
        lines.append(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
        )

    add_field("model", model)
    add_field("language", "en")
    add_field("response_format", "json")

    lines.append(f"--{boundary}\r\n".encode())
    lines.append(
        b'Content-Disposition: form-data; name="file"; filename="audio.wav"\r\n'
    )
    lines.append(b"Content-Type: audio/wav\r\n\r\n")
    lines.append(wav)
    lines.append(b"\r\n")
    lines.append(f"--{boundary}--\r\n".encode())
    return b"".join(lines), boundary


def transcribe(pcm: bytes, sample_rate: int) -> str:
    if not configured():
        raise RuntimeError("OpenAI ASR not configured")

    pcm16 = _prepare_pcm(pcm, sample_rate)
    if len(pcm16) < TARGET_RATE * 0.35 * 2:
        return ""

    wav = _pcm_to_wav(pcm16, TARGET_RATE)
    body, boundary = _multipart_body(wav, asr_model())
    url = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").strip().rstrip(
        "/"
    ) + "/audio/transcriptions"

    req = urllib.request.Request(
        url,
        data=body,
        headers={
            "Authorization": f"Bearer {os.environ['OPENAI_API_KEY'].strip()}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        log.error("openai asr http %s: %s", exc.code, detail[:500])
        raise RuntimeError(f"OpenAI ASR HTTP {exc.code}") from exc
    except Exception as exc:
        log.exception("openai asr failed")
        raise RuntimeError(f"OpenAI ASR error: {exc}") from exc

    return (data.get("text") or "").strip()
