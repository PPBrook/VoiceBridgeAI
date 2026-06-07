#!/usr/bin/env bash
# 将 dist/*.app 打成 releases/*.zip（勿用 ditto 更新已有 zip，易产生 CRC 损坏）
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

if [[ ! -d "$APP" ]]; then
  echo "未找到 $APP，请先运行 build-app-${VARIANT}.sh" >&2
  exit 1
fi

xattr -cr "$APP"
rm -f "$ZIP"
(
  cd "$ROOT/dist"
  COPYFILE_DISABLE=1 zip -r -X -y "$ZIP" "$APP_NAME.app"
)

echo "已生成: $ZIP ($(du -sh "$ZIP" | awk '{print $1}'))"
unzip -t "$ZIP" >/dev/null
echo "zip 校验通过"
