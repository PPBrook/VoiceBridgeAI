#!/usr/bin/env bash
# 打包时将仓库根目录 .env 中的云端密钥合并进 bundle-seed.env
append_bundle_env_secrets() {
  local dest="$1"
  local repo_root="$2"

  if [[ -n "${BUNDLE_SECRETS_FILE:-}" && -f "$BUNDLE_SECRETS_FILE" ]]; then
    {
      echo ""
      echo "# --- bundled credentials (BUNDLE_SECRETS_FILE) ---"
      cat "$BUNDLE_SECRETS_FILE"
    } >>"$dest"
    echo "已合并 BUNDLE_SECRETS_FILE: $BUNDLE_SECRETS_FILE"
    return 0
  fi

  if [[ "${BUNDLE_SECRETS_FROM_REPO_ENV:-1}" != "1" || ! -f "$repo_root/.env" ]]; then
    echo "提示: 未合并云端密钥（仓库根目录无 .env 或 BUNDLE_SECRETS_FROM_REPO_ENV=0）"
    return 0
  fi

  local extracted
  extracted="$(grep -E '^(TENCENT_|OPENAI_|QINIU_|ALIYUN_|DEEPSEEK_|DEEPL_|BAIDU_|GOOGLE_)' "$repo_root/.env" \
    | grep -v '^[[:space:]]*#' || true)"
  if [[ -z "$extracted" ]]; then
    echo "提示: .env 中未找到云端密钥行（TENCENT_/OPENAI_/…）"
    return 0
  fi

  {
    echo ""
    echo "# --- from repo .env at build time ---"
    echo "$extracted"
  } >>"$dest"
  echo "已从仓库 .env 合并云端密钥"
}

verify_bundled_models() {
  local models_dir="$1"
  local ok=1

  if [[ ! -f "$models_dir/whisper/.installed-tiny.en" ]]; then
    echo "错误: 缺少 Whisper 标记 $models_dir/whisper/.installed-tiny.en" >&2
    ok=0
  fi
  if [[ ! -f "$models_dir/argos/.installed-en-zh" ]]; then
    echo "错误: 缺少 Argos 标记 $models_dir/argos/.installed-en-zh" >&2
    ok=0
  fi
  local hub="$models_dir/hf/hub"
  if [[ ! -d "$hub" ]] || [[ -z "$(ls -A "$hub" 2>/dev/null || true)" ]]; then
    echo "错误: Whisper HF 缓存为空 ($hub)" >&2
    ok=0
  fi
  local pkg="$models_dir/argos/packages"
  if [[ ! -d "$pkg" ]] || [[ -z "$(ls -A "$pkg" 2>/dev/null || true)" ]]; then
    echo "错误: Argos 语言包为空 ($pkg)" >&2
    ok=0
  fi

  if [[ "$ok" -eq 0 ]]; then
    echo "本地模型未完整打入 App。可设置 VOICEBRIDGE_MODELS_SOURCE 或检查网络后重试。" >&2
    exit 1
  fi
  echo "已验证内置模型: Whisper tiny.en + Argos en→zh"
}
