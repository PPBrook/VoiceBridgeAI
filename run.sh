#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
[[ -d .venv ]] || python3 -m venv .venv
source .venv/bin/activate
pip install -q -r requirements.txt
PORT="${VOICEBRIDGE_PORT:-8765}"
if command -v lsof >/dev/null 2>&1; then
  OLD_PID="$(lsof -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$OLD_PID" ]]; then
    echo "端口 $PORT 已被占用 (PID $OLD_PID)"
    exit 1
  fi
fi
echo "VoiceBridgeAI engine — http://127.0.0.1:$PORT"
cd server && python main.py
