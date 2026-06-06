#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export VOICEBRIDGE_ROOT="$(cd "$ROOT/../.." && pwd)"
echo "VoiceBridgeAI 原生客户端 — 仓库: $VOICEBRIDGE_ROOT"
swift build -c release
echo ""
echo "运行: $ROOT/.build/release/VoiceBridgeAI"
echo "打包: $ROOT/build-app.sh → dist/VoiceBridgeAI.app"
echo ""
exec "$ROOT/.build/release/VoiceBridgeAI"
