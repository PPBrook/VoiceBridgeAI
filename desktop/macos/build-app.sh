#!/usr/bin/env bash
# 构建独立 App：./build-app.sh cloud | local
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/../.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
source "$ROOT/scripts/bundle-seed/merge-demo-secrets.sh"

VARIANT="${1:-}"
if [[ "$VARIANT" != "cloud" && "$VARIANT" != "local" ]]; then
  echo "用法: $0 cloud|local" >&2
  echo "  cloud — 仅云端 API，无本地模型依赖" >&2
  echo "  local — 内置 Whisper tiny.en + Argos en→zh" >&2
  exit 1
fi

SKIP_VENV="${SKIP_VENV:-0}"
SKIP_MODELS="${SKIP_MODELS:-0}"

case "$VARIANT" in
  cloud)
    APP_NAME="VoiceBridgeAI-Cloud"
    BUNDLE_ID="ai.voicebridge.desktop.cloud"
    DISPLAY_NAME="VoiceBridgeAI 云端"
    REQUIREMENTS="$REPO_ROOT/requirements-cloud.txt"
    SEED="$ROOT/scripts/bundle-seed/cloud.env"
    ;;
  local)
    APP_NAME="VoiceBridgeAI-Local"
    BUNDLE_ID="ai.voicebridge.desktop.local"
    DISPLAY_NAME="VoiceBridgeAI 本地"
    REQUIREMENTS="$REPO_ROOT/requirements.txt"
    SEED="$ROOT/scripts/bundle-seed/local.env"
    ;;
esac

echo "编译 Swift release …"
swift build -c release

BIN="$ROOT/.build/release/VoiceBridgeAI"
APP="$ROOT/dist/${APP_NAME}.app"
MACOS="$APP/Contents/MacOS"
RES="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$MACOS" "$RES"

cp "$BIN" "$MACOS/VoiceBridgeAI"
chmod +x "$MACOS/VoiceBridgeAI"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $DISPLAY_NAME" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :VoiceBridgeBundleVariant string $VARIANT" "$APP/Contents/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :VoiceBridgeBundleVariant $VARIANT" "$APP/Contents/Info.plist"

echo "$VARIANT" >"$RES/bundle-variant.txt"
cp "$SEED" "$RES/bundle-seed.env"
if [[ "$VARIANT" == "local" || "${BUNDLE_DEMO_SECRETS:-0}" == "1" ]]; then
  append_bundle_env_secrets "$RES/bundle-seed.env" "$REPO_ROOT"
fi

echo "复制 Python server …"
rsync -a --exclude '__pycache__' --exclude '*.pyc' "$REPO_ROOT/server/" "$RES/server/"
cp "$REQUIREMENTS" "$RES/requirements.txt"
cp "$ROOT/scripts/run-server.sh" "$RES/run-server.sh"
chmod +x "$RES/run-server.sh"

if [[ "$SKIP_VENV" == "1" ]]; then
  echo "SKIP_VENV=1 — 跳过 venv（.app 无法独立运行）"
else
  echo "创建内置 Python 环境（${VARIANT}）…"

  bundled_python() {
    if [[ -x "$RES/python-venv/bin/python" ]]; then
      echo "$RES/python-venv/bin/python"
    elif [[ -x "$RES/python-venv/bin/python3" ]]; then
      echo "$RES/python-venv/bin/python3"
    fi
  }

  verify_bundled_venv() {
    local py
    py="$(bundled_python)" || return 1
    "$py" -c "import uvicorn, fastapi, websockets" || return 1
    if [[ "$VARIANT" == "local" ]]; then
      "$py" -c "import faster_whisper, argostranslate" || return 1
    fi
  }

  pip_install_with_retry() {
    local req="$1"
    local max="${PIP_INSTALL_ATTEMPTS:-4}"
    local n=1
    pip install --upgrade pip
    while (( n <= max )); do
      echo "pip install (${n}/${max}) …"
      if pip install --retries 5 --default-timeout=180 -r "$req"; then
        return 0
      fi
      echo "pip 网络中断，${n}/${max} 失败，重试…" >&2
      ((n++)) || true
      sleep 3
    done
    echo "pip install 多次失败。若仓库已有可用 .venv，可设 BUNDLE_COPY_VENV=1 后重试。" >&2
    return 1
  }

  create_fresh_bundled_venv() {
    rm -rf "$RES/python-venv"
    python3 -m venv "$RES/python-venv"
    # shellcheck disable=SC1091
    source "$RES/python-venv/bin/activate"
    pip_install_with_retry "$RES/requirements.txt"
    deactivate
  }

  # cloud 默认不复用仓库 .venv（开发 .venv 含 Whisper/Argos，体积 ~1GB）
  default_copy_venv=1
  if [[ "$VARIANT" == "cloud" ]]; then
    default_copy_venv=0
  fi

  repo_venv_ready=0
  if [[ "${BUNDLE_COPY_VENV:-$default_copy_venv}" == "1" ]]; then
    if [[ -x "$REPO_ROOT/.venv/bin/python" || -x "$REPO_ROOT/.venv/bin/python3" ]]; then
      repo_venv_ready=1
    fi
  fi

  if [[ "$repo_venv_ready" == "1" ]]; then
    echo "复用仓库 .venv → python-venv（跳过 pip 下载，推荐）"
    rm -rf "$RES/python-venv"
    rsync -a \
      --exclude '__pycache__' \
      --exclude '*.pyc' \
      "$REPO_ROOT/.venv/" "$RES/python-venv/"
    if ! verify_bundled_venv; then
      echo "复用 .venv 校验失败（可能 Python 版本或依赖不完整），改为在 .app 内重新 pip install …" >&2
      create_fresh_bundled_venv
    fi
  else
    create_fresh_bundled_venv
  fi

  if ! verify_bundled_venv; then
    echo "错误: 内置 python-venv 不可用，请先在仓库根目录 ./run.sh 创建 .venv，或检查网络后重试打包。" >&2
    exit 1
  fi
  echo "内置 python-venv 校验通过: $(bundled_python)"
  # Python 3.14 venv 的 Unicode 别名 𝜋thon 会导致 Finder 解压 zip 失败
  if [[ -d "$RES/python-venv/bin" ]]; then
    for _vb in "$RES/python-venv/bin"/*; do
      [[ -e "$_vb" ]] || continue
      _name=$(basename "$_vb")
      if ! LC_ALL=C printf '%s' "$_name" | grep -qE '^[!-~]+$'; then
        echo "移除 venv 非 ASCII 条目: $_name"
        rm -f "$_vb"
      fi
    done
  fi
fi

if [[ "$VARIANT" == "local" && "$SKIP_VENV" != "1" && "$SKIP_MODELS" != "1" ]]; then
  MODELS_DIR="$RES/bundled-models"
  mkdir -p "$MODELS_DIR"
  if [[ -n "${VOICEBRIDGE_MODELS_SOURCE:-}" && -f "${VOICEBRIDGE_MODELS_SOURCE}/whisper/.installed-tiny.en" ]]; then
    echo "复制已有本地模型: $VOICEBRIDGE_MODELS_SOURCE → bundled-models"
    rsync -a "${VOICEBRIDGE_MODELS_SOURCE}/" "$MODELS_DIR/"
    if [[ -d "${ARGOS_PACKAGES_SOURCE:-$HOME/.local/share/argos-translate/packages}" ]]; then
      mkdir -p "$MODELS_DIR/argos/packages"
      rsync -a "${ARGOS_PACKAGES_SOURCE:-$HOME/.local/share/argos-translate/packages}/" \
        "$MODELS_DIR/argos/packages/"
    fi
  else
    echo "下载内置模型（Whisper tiny.en + Argos en→zh，需网络，约 3–10 分钟）…"
    # shellcheck disable=SC1091
    source "$RES/python-venv/bin/activate"
    export VOICEBRIDGE_MODELS_DIR="$MODELS_DIR"
    cd "$REPO_ROOT/server"
    python "$ROOT/scripts/prepare-bundled-models.py"
    deactivate
    cd "$ROOT"
  fi
  verify_bundled_models "$MODELS_DIR"
fi

echo ""
echo "已生成: $APP"
du -sh "$APP" 2>/dev/null || true
echo ""
case "$VARIANT" in
  cloud)
    echo "云端版 — 用户需："
    echo "  1. 拖入「应用程序」→ 授予屏幕录制"
    echo "  2. 设置 → 接口密钥（腾讯 ASR / 翻译等）"
    echo "  3. 开始悬浮字幕"
    ;;
  local)
    echo "本地版 — 用户需："
    echo "  1. 拖入「应用程序」→ 授予屏幕录制"
    echo "  2. 直接开始（可内置 Whisper + Argos）"
    ;;
esac
echo ""
echo "配置: ~/Library/Application Support/$APP_NAME/"
echo "侧车日志: ~/Library/Application Support/$APP_NAME/server.log"
