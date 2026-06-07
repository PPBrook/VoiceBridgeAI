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

if [[ -f "$DIR/bundle-variant.txt" ]]; then
  export VOICEBRIDGE_BUNDLE_VARIANT="$(tr -d '[:space:]' < "$DIR/bundle-variant.txt")"
fi

if [[ "${VOICEBRIDGE_BUNDLE_VARIANT:-}" == "local" && -d "$DIR/bundled-models" ]]; then
  export VOICEBRIDGE_MODELS_DIR="$DIR/bundled-models"
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

export VOICEBRIDGE_DATA_DIR="$DATA"

case "${VOICEBRIDGE_BUNDLE_VARIANT:-}" in
  cloud)
    export VOICEBRIDGE_OPTIONAL_LOCAL_MODELS="${VOICEBRIDGE_OPTIONAL_LOCAL_MODELS:-1}"
    export LOCAL_WHISPER_ENABLED="${LOCAL_WHISPER_ENABLED:-0}"
    export LOCAL_ARGOS_ENABLED="${LOCAL_ARGOS_ENABLED:-0}"
    ;;
  local)
    export VOICEBRIDGE_OPTIONAL_LOCAL_MODELS="${VOICEBRIDGE_OPTIONAL_LOCAL_MODELS:-0}"
    export LOCAL_WHISPER_ENABLED="${LOCAL_WHISPER_ENABLED:-1}"
    export LOCAL_ARGOS_ENABLED="${LOCAL_ARGOS_ENABLED:-1}"
    if [[ -d "$DIR/bundled-models" ]]; then
      export VOICEBRIDGE_MODELS_DIR="$DIR/bundled-models"
    fi
    ;;
  *)
    export VOICEBRIDGE_OPTIONAL_LOCAL_MODELS="${VOICEBRIDGE_OPTIONAL_LOCAL_MODELS:-1}"
    ;;
esac

{
  echo "=== $(date) VoiceBridgeAI sidecar start (variant=${VOICEBRIDGE_BUNDLE_VARIANT:-dev}) ==="
  cd "$DIR/server"
  exec python main.py
} >>"$LOG" 2>&1
