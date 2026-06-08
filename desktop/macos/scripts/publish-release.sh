#!/usr/bin/env bash
# 将 dist/*.app 打包为 releases/*.zip
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
ZIP_TMP="${ZIP}.part"
STAGE="$(mktemp -d)"

cleanup() { rm -rf "$STAGE" "$ZIP_TMP"; }
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

verify_zip() {
  local z="$1"
  echo "校验 zip …"
  unzip -t "$z" >/dev/null
  local tmp
  tmp="$(mktemp -d)"
  ditto -xk "$z" "$tmp"
  test -x "$tmp/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"
  rm -rf "$tmp"
  echo "zip 校验通过"
}

echo "准备发布副本 …"
ditto --norsrc --noextattr --noqtn "$APP" "$STAGE/$APP_NAME.app"
resolve_symlinks "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/bin"
sanitize_venv_bin "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/bin"
rm -f "$STAGE/$APP_NAME.app/Contents/Resources/python-venv/.gitignore"
test -x "$STAGE/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"

echo "打包 zip（大体积请耐心等待，勿中断）…"
rm -f "$ZIP_TMP" "$REPO_ROOT/releases/$APP_NAME.tar.gz" "$REPO_ROOT/releases/$APP_NAME.tar"
# zip -0：仅存储不压缩，大体积更稳；比 ditto -c -k 不易产生半截 zip
(
  cd "$STAGE"
  zip -0 -r -q "$ZIP_TMP" "$APP_NAME.app"
)
verify_zip "$ZIP_TMP"
rm -f "$ZIP"
mv "$ZIP_TMP" "$ZIP"
trap - EXIT
rm -rf "$STAGE"

echo "已发布: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
echo "解压: ditto -xk releases/$APP_NAME.zip . && xattr -cr $APP_NAME.app"
