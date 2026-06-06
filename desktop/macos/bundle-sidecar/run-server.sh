#!/usr/bin/env bash
# Bundled inside VoiceBridgeAI.app/Contents/Resources/
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
VENV="$DIR/python-venv"
DATA="${VOICEBRIDGE_DATA_DIR:-$HOME/Library/Application Support/VoiceBridgeAI}"
LOG="$DATA/server.log"
mkdir -p "$DATA"

if [[ ! -x "$VENV/bin/python" ]]; then
  echo "VoiceBridgeAI: bundled Python venv missing at $VENV" >>"$LOG"
  exit 1
fi

# shellcheck disable=SC1091
source "$VENV/bin/activate"

ENV_FILE="$DATA/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

export VOICEBRIDGE_OPTIONAL_LOCAL_MODELS="${VOICEBRIDGE_OPTIONAL_LOCAL_MODELS:-1}"
export VOICEBRIDGE_DATA_DIR="$DATA"

{
  echo "=== $(date) VoiceBridgeAI sidecar start ==="
  cd "$DIR/server"
  exec python main.py
} >>"$LOG" 2>&1
