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
  echo "提示: 未找到 .env → 请 cp .env.example .env（本地模式可只设 ASR_MODE=local）"
fi
[[ -d .venv ]] || python3 -m venv .venv
source .venv/bin/activate
pip install -q -r "$ROOT/requirements.txt"
cd "$ROOT/server" && python main.py
