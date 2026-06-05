"""VoiceBridgeAI — PR #1: project scaffold + health check."""

from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "static"

app = FastAPI(title="VoiceBridgeAI", version="0.1.0")

FEATURES = [
    "static-page",
    "health-api",
]


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "version": "0.1.0",
        "pr": 1,
        "features": FEATURES,
    }


@app.get("/")
def index():
    return FileResponse(STATIC / "index.html")


app.mount("/static", StaticFiles(directory=STATIC), name="static")


if __name__ == "__main__":
    import uvicorn

    print("VoiceBridgeAI PR#1 — http://localhost:8765")
    print("Health check — http://localhost:8765/api/health")
    uvicorn.run("main:app", host="0.0.0.0", port=8765, reload=False)
