"""Tencent Cloud real-time ASR (WebSocket streaming)."""

from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import json
import logging
import os
import random
import time
import uuid
from collections.abc import Awaitable, Callable
from typing import Any
from urllib.parse import quote

import websockets
from websockets.asyncio.client import ClientConnection

log = logging.getLogger(__name__)

OnResult = Callable[[int, str, bool], Awaitable[None]]


def configured() -> bool:
    return bool(
        os.environ.get("TENCENT_ASR_APP_ID", "").strip()
        and os.environ.get("TENCENT_ASR_SECRET_ID", "").strip()
        and os.environ.get("TENCENT_ASR_SECRET_KEY", "").strip()
    )


def engine_model() -> str:
    return os.environ.get("TENCENT_ASR_ENGINE", "16k_en")


def build_ws_url(voice_id: str) -> str:
    app_id = os.environ["TENCENT_ASR_APP_ID"].strip()
    secret_id = os.environ["TENCENT_ASR_SECRET_ID"].strip()
    secret_key = os.environ["TENCENT_ASR_SECRET_KEY"].strip()

    timestamp = int(time.time())
    expired = timestamp + 86400
    nonce = random.randint(1, 9999999999)
    params = {
        "engine_model_type": engine_model(),
        "expired": str(expired),
        "needvad": "1",
        "nonce": str(nonce),
        "secretid": secret_id,
        "timestamp": str(timestamp),
        "voice_format": "1",
        "voice_id": voice_id,
    }
    query = "&".join(f"{k}={params[k]}" for k in sorted(params))
    sign_str = f"asr.cloud.tencent.com/asr/v2/{app_id}?{query}"
    digest = hmac.new(
        secret_key.encode("utf-8"),
        sign_str.encode("utf-8"),
        hashlib.sha1,
    ).digest()
    signature = quote(base64.b64encode(digest).decode("utf-8"), safe="")
    return f"wss://asr.cloud.tencent.com/asr/v2/{app_id}?{query}&signature={signature}"


class TencentAsrStream:
    """Forward 16k PCM to Tencent and invoke callbacks for partial/final text."""

    def __init__(self, on_result: OnResult) -> None:
        self._on_result = on_result
        self._ws: ClientConnection | None = None
        self._recv_task: asyncio.Task | None = None
        self._closed = False

    async def start(self) -> None:
        if not configured():
            raise RuntimeError(
                "Tencent ASR not configured: set TENCENT_ASR_APP_ID, "
                "TENCENT_ASR_SECRET_ID, TENCENT_ASR_SECRET_KEY in .env"
            )
        voice_id = uuid.uuid4().hex
        url = build_ws_url(voice_id)
        log.info("connecting tencent asr voice_id=%s engine=%s", voice_id, engine_model())
        # Bypass system SOCKS/HTTP proxy — Tencent ASR needs a direct wss connection.
        self._ws = await websockets.connect(
            url,
            ping_interval=20,
            ping_timeout=60,
            proxy=None,
        )
        raw = await asyncio.wait_for(self._ws.recv(), timeout=15)
        data = json.loads(raw)
        if data.get("code") != 0:
            await self._ws.close()
            raise RuntimeError(f"Tencent ASR handshake failed: {data.get('message')}")
        self._recv_task = asyncio.create_task(self._recv_loop())
        log.info("tencent asr ready")

    async def send_pcm(self, pcm: bytes) -> None:
        if self._closed or not self._ws or not pcm:
            return
        await self._ws.send(pcm)

    async def close(self) -> None:
        if self._closed:
            return
        self._closed = True
        if self._recv_task:
            self._recv_task.cancel()
            try:
                await self._recv_task
            except asyncio.CancelledError:
                pass
            self._recv_task = None
        if self._ws:
            try:
                await self._ws.send(json.dumps({"type": "end"}))
                await asyncio.wait_for(self._ws.recv(), timeout=5)
            except Exception:
                pass
            try:
                await self._ws.close()
            except Exception:
                pass
            self._ws = None
        log.info("tencent asr closed")

    async def _recv_loop(self) -> None:
        assert self._ws is not None
        try:
            async for raw in self._ws:
                if isinstance(raw, bytes):
                    continue
                data = json.loads(raw)
                if data.get("code") != 0:
                    log.error("tencent asr error: %s", data.get("message"))
                    continue
                if data.get("final") == 1:
                    break
                result = data.get("result") or {}
                text = (result.get("voice_text_str") or "").strip()
                if not text:
                    continue
                index = int(result.get("index", 0))
                slice_type = int(result.get("slice_type", 0))
                if slice_type == 1:
                    await self._on_result(index, text, False)
                elif slice_type == 2:
                    await self._on_result(index, text, True)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            log.exception("tencent asr recv failed: %s", exc)
