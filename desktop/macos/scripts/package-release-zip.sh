#!/usr/bin/env bash
# 将 dist/*.app 打成 releases/*.zip（与 Local 包相同：ditto 全新创建，勿覆盖更新）
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
CHECKSUMS="$REPO_ROOT/releases/SHA256SUMS"

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP，请先运行 build-app-${VARIANT}.sh" >&2
  exit 1
fi

xattr -cr "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "已生成: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
unzip -t "$ZIP" >/dev/null
TMP="$(mktemp -d)"
ditto -xk "$ZIP" "$TMP"
test -x "$TMP/$APP_NAME.app/Contents/MacOS/VoiceBridgeAI"
rm -rf "$TMP"
echo "zip 校验通过（unzip + ditto 解压）"

# 更新 SHA256SUMS（供下载后核对是否完整）
(
  cd "$REPO_ROOT/releases"
  sha256=$(shasum -a 256 "$APP_NAME.zip" | awk '{print $1}')
  if [[ -f "$CHECKSUMS" ]]; then
    grep -v " $APP_NAME.zip$" "$CHECKSUMS" > "${CHECKSUMS}.tmp" || true
    mv "${CHECKSUMS}.tmp" "$CHECKSUMS"
  fi
  echo "$sha256  $APP_NAME.zip" >> "$CHECKSUMS"
)
echo "SHA256: $(grep " $APP_NAME.zip$" "$CHECKSUMS" | awk '{print $1}')"
