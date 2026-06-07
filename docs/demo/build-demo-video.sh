#!/usr/bin/env bash
# 重新生成 docs/demo/VoiceBridgeAI-demo.mp4（需仓库根 .venv 含 pillow、系统 ffmpeg）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec "$ROOT/../../.venv/bin/python" "$ROOT/build-demo-video.py"
