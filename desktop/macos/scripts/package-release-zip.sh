#!/usr/bin/env bash
# 将 dist/*.app 打成 releases/*.zip（兼容 Finder 双击 / 归档实用工具）
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

# 复制到临时目录，展开符号链接、去掉 xattr（避免 ._ 文件导致归档实用工具报损坏）
echo "准备发布副本 …"
ditto --norsrc --noextattr --noqtn "$APP" "$STAGE/$APP_NAME.app"

resolve_symlinks() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  local item target resolved next
  for item in "$dir"/*; do
    [[ -L "$item" ]] || continue
    resolved=$(readlink "$item")
    while [[ -L "$resolved" || ( "$resolved" != /* && -L "$(dirname "$item")/$resolved" ) ]]; do
      if [[ "$resolved" == /* ]]; then
        next=$(readlink "$resolved")
      else
        next=$(readlink "$(dirname "$item")/$resolved")
      fi
      [[ -z "$next" ]] && break
      if [[ "$next" == /* ]]; then
        resolved="$next"
      else
        resolved="$(cd "$(dirname "$item")" && cd "$(dirname "$resolved")" && pwd)/$next"
      fi
    done
    if [[ "$resolved" != /* ]]; then
      resolved="$(dirname "$item")/$resolved"
    fi
    rm "$item"
    cp -p "$resolved" "$item"
  done
}

resolve_symlinks "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/bin"

rm -f "$ZIP"
(
  cd "$STAGE"
  COPYFILE_DISABLE=1 zip -r -X "$ZIP" "$APP_NAME.app"
)

echo "已生成: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
unzip -t "$ZIP" >/dev/null

TMP="$(mktemp -d)"
ditto -xk "$ZIP" "$TMP"
test -x "$TMP/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"

AU_TEST="$(mktemp -d)"
cp "$ZIP" "$AU_TEST/"
if open -W -a /System/Library/CoreServices/Applications/Archive\ Utility.app "$AU_TEST/$(basename "$ZIP")" 2>/dev/null; then
  test -d "$AU_TEST/$APP_NAME.app"
  echo "zip 校验通过（unzip + ditto + 归档实用工具）"
else
  # open -W 在部分环境不可用，回退 unzip 校验
  (
    cd "$AU_TEST"
    unzip -q "$(basename "$ZIP")"
  )
  test -d "$AU_TEST/$APP_NAME.app"
  echo "zip 校验通过（unzip + ditto）"
fi
rm -rf "$TMP" "$AU_TEST"
