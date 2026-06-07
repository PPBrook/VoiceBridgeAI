#!/usr/bin/env bash
# 将 dist/*.app 打成 releases/*.zip（cloud 另含 .tar.gz，兼容 Finder 双击）
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
TAR="$REPO_ROOT/releases/$APP_NAME.tar.gz"
STAGE="$(mktemp -d)"

cleanup() { rm -rf "$STAGE"; }
trap cleanup EXIT

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP，请先运行 build-app-${VARIANT}.sh" >&2
  exit 1
fi

# Python 3.14 venv 会生成 Unicode 别名 𝜋thon，归档实用工具解压 zip 时会失败
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

rm -f "$ZIP"
(
  cd "$STAGE"
  COPYFILE_DISABLE=1 zip -r -X "$ZIP" "$APP_NAME.app"
)

echo "已生成: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
unzip -t "$ZIP" >/dev/null

if [[ "$VARIANT" == "cloud" ]]; then
  rm -f "$TAR"
  COPYFILE_DISABLE=1 tar -czf "$TAR" -C "$STAGE" "$APP_NAME.app"
  echo "已生成: $TAR ($(du -sh "$TAR" | awk '{print $1}'))"
fi

verify_archive() {
  local archive="$1"
  local au_dir
  au_dir="$(mktemp -d)"
  cp "$archive" "$au_dir/"
  if open -W -a /System/Library/CoreServices/Applications/Archive\ Utility.app "$au_dir/$(basename "$archive")" 2>/dev/null; then
    test -d "$au_dir/$APP_NAME.app"
  else
    case "$archive" in
      *.tar.gz) tar -xzf "$archive" -C "$au_dir" ;;
      *.zip)
        (
          cd "$au_dir"
          unzip -q "$(basename "$archive")"
        ) ;;
    esac
    test -d "$au_dir/$APP_NAME.app"
  fi
  rm -rf "$au_dir"
}

TMP="$(mktemp -d)"
ditto -xk "$ZIP" "$TMP"
test -x "$TMP/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"
rm -rf "$TMP"

verify_archive "$ZIP"
echo "zip 校验通过（ditto + 归档实用工具）"

if [[ "$VARIANT" == "cloud" && -f "$TAR" ]]; then
  verify_archive "$TAR"
  echo "tar.gz 校验通过（归档实用工具）"
fi

# 确认 zip 内无 Unicode venv 条目
if unzip -l "$ZIP" | LC_ALL=C grep -q 'python-venv/bin/[^[:print:]]'; then
  echo "错误: zip 仍含非 ASCII venv 路径" >&2
  exit 1
fi
