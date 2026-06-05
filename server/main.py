"""VoiceBridgeAI — Chrome tab capture + WebSocket PCM stream."""

import json
import logging
from pathlib import Path

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "static"

logging.basicConfig(level=logging.INFO)
log = logging.getLogger(__name__)

app = FastAPI(title="VoiceBridgeAI", version="0.1.0")

FEATURES = [
    "static-page",
    "health-api",
    "tab-capture",
    "websocket-pcm",
]


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "pr": 3,
        "features": FEATURES,
    }


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


@app.websocket("/ws")
async def websocket_pcm(ws: WebSocket):
    await ws.accept()
    sample_rate = 0
    pcm_bytes = 0
    log.info("client connected")

    try:
        while True:
            msg = await ws.receive()
            if msg.get("type") == "websocket.disconnect":
                break

            if "text" in msg and msg["text"]:
                data = json.loads(msg["text"])
                if data.get("type") == "config":
                    sample_rate = int(data.get("sampleRate", 0))
                    log.info("config sampleRate=%s", sample_rate)

            if "bytes" in msg and msg["bytes"]:
                pcm_bytes += len(msg["bytes"])
                if pcm_bytes % 65536 < len(msg["bytes"]):
                    log.info("pcm received %d bytes @ %d Hz", pcm_bytes, sample_rate)

    except WebSocketDisconnect:
        pass
    finally:
        log.info("client disconnected (%d bytes)", pcm_bytes)


app.mount("/static", StaticFiles(directory=STATIC), name="static")


if __name__ == "__main__":
    import uvicorn

    print("VoiceBridgeAI — http://127.0.0.1:8765")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8765,
        reload=False,
        ws_ping_interval=20,
        ws_ping_timeout=60,
    )
