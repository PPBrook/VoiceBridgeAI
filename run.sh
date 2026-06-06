#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo "VoiceBridgeAI — 工作目录: $ROOT"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
  echo "已加载 .env"
else
  echo "提示: 未找到 .env → 请 cp .env.example .env（全本地可设 ASR_PROVIDER=local）"
fi
[[ -d .venv ]] || python3 -m venv .venv
source .venv/bin/activate
pip install -q -r "$ROOT/requirements.txt"
PORT="${VOICEBRIDGE_PORT:-8765}"
if command -v lsof >/dev/null 2>&1; then
  OLD_PID="$(lsof -t -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
  if [[ -n "$OLD_PID" ]]; then
    echo "端口 $PORT 已被占用 (PID $OLD_PID)，可能是其他终端或 Cursor 后台任务。"
    echo "释放端口: kill $OLD_PID"
    echo "或直接访问: http://127.0.0.1:$PORT"
    exit 1
  fi
fi
echo "VoiceBridgeAI — http://127.0.0.1:$PORT"
cd "$ROOT/server" && python main.py
