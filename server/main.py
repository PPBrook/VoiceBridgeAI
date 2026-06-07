"""VoiceBridgeAI — tab capture, PCM, multi-provider ASR / translate / revise."""

import os

from app_bootstrap import create_app

app = create_app()

if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("VOICEBRIDGE_PORT", "8765"))
    print(f"VoiceBridgeAI — http://127.0.0.1:{port}")
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        ws_ping_interval=20,
        ws_ping_timeout=120,
    )
