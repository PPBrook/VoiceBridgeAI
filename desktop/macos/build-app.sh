#!/usr/bin/env bash
# 打包独立 VoiceBridgeAI.app（内置 Python 引擎侧车，无需仓库 / run.sh）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
cd "$ROOT"

SKIP_VENV="${SKIP_VENV:-0}"

echo "编译 Swift release …"
swift build -c release

BIN="$ROOT/.build/release/VoiceBridgeAI"
APP="$ROOT/dist/VoiceBridgeAI.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$BIN" "$MACOS/VoiceBridgeAI"
chmod +x "$MACOS/VoiceBridgeAI"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

echo "复制 Python server …"
rsync -a --exclude '__pycache__' --exclude '*.pyc' "$REPO_ROOT/server/" "$RES/server/"
cp "$REPO_ROOT/requirements.txt" "$RES/requirements.txt"
cp "$ROOT/scripts/run-server.sh" "$RES/run-server.sh"
chmod +x "$RES/run-server.sh"

if [[ "$SKIP_VENV" == "1" ]]; then
  echo "SKIP_VENV=1 — 跳过 venv（仅开发调试 Swift UI，.app 无法独立运行）"
else
  echo "创建内置 Python 环境（首次约 3–8 分钟，取决于网络）…"
  python3 -m venv "$RES/python-venv"
  # shellcheck disable=SC1091
  source "$RES/python-venv/bin/activate"
  pip install -q --upgrade pip
  pip install -q -r "$RES/requirements.txt"
  deactivate
fi

echo ""
echo "已生成: $APP"
du -sh "$APP" 2>/dev/null || true
echo ""
echo "独立安装版 — 用户只需："
echo "  1. 将 VoiceBridgeAI.app 拖入「应用程序」"
echo "  2. 双击打开，授予屏幕录制权限"
echo "  3. 设置 → 本地模型 / 接口密钥 → 开始字幕"
echo ""
echo "配置与日志: ~/Library/Application Support/VoiceBridgeAI/"
echo "侧车日志:   ~/Library/Application Support/VoiceBridgeAI/server.log"
