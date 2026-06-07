#!/usr/bin/env bash
# 将 dist/*.app 打包为 releases/*.zip（推荐评审下载）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
VARIANT="${1:-}"
if [[ "$VARIANT" != "cloud" && "$VARIANT" != "local" ]]; then
  echo "用法: $0 cloud|local" >&2
  exit 1
fi

case "$VARIANT" in
  cloud) APP_NAME="VoiceBridgeAI-Cloud" ;;
  local) APP_NAME="VoiceBridgeAI-Local" ;;
esac

APP="$ROOT/dist/$APP_NAME.app"
ZIP="$REPO_ROOT/releases/$APP_NAME.zip"
STAGE="$(mktemp -d)"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP，请先运行 build-app-${VARIANT}.sh" >&2
  exit 1
fi

sanitize_venv_bin() {
  local bindir="$1"
  [[ -d "$bindir" ]] || return 0
  local f b
  for f in "$bindir"/*; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    if ! LC_ALL=C printf '%s' "$b" | grep -qE '^[!-~]+$'; then
      echo "移除 venv 非 ASCII 条目: $b"
      rm -f "$f"
    fi
  done
}

resolve_symlinks() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local item real
  for item in "$dir"/*; do
    [[ -L "$item" ]] || continue
    real=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$item")
    rm "$item"
    cp -p "$real" "$item"
  done
}

echo "准备发布副本 …"
ditto --norsrc --noextattr --noqtn "$APP" "$STAGE/$APP_NAME.app"
resolve_symlinks "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/bin"
sanitize_venv_bin "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/bin"
rm -f "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/.gitignore"
test -x "$STAGE/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"

echo "打包 zip …"
rm -f "$ZIP" "$REPO_ROOT/releases/$APP_NAME.tar.gz" "$REPO_ROOT/releases/$APP_NAME.tar"
ditto -c -k --sequesterRsrc --keepParent "$STAGE/$APP_NAME.app" "$ZIP"
rm -rf "$REPO_ROOT/releases/$APP_NAME.app"

echo "已发布: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
echo "解压: ditto -xk releases/$APP_NAME.zip ."
