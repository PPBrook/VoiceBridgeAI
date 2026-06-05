#!/usr/bin/env bash
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
echo "VoiceBridgeAI — 工作目录: $ROOT"
[[ -d .venv ]] || python3 -m venv .venv
source .venv/bin/activate
pip install -q -r "$ROOT/requirements.txt"
cd "$ROOT/server" && python main.py
