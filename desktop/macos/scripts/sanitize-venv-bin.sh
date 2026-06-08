#!/usr/bin/env bash
# 移除 python-venv/bin 中非 ASCII 文件名（如 Python 3.14 的 𝜋thon 别名）。
# Finder / Archive Utility 解压含此类路径的 zip 会失败或损坏 .app。
set -euo pipefail

sanitize_venv_bin() {
  local bindir="${1:?用法: sanitize-venv-bin.sh /path/to/python-venv/bin}"
  [[ -d "$bindir" ]] || return 0
  local f b removed=0
  for f in "$bindir"/*; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    if ! LC_ALL=C printf '%s' "$b" | grep -qE '^[!-~]+$'; then
      echo "移除 venv 非 ASCII 条目: $b"
      rm -f "$f"
      removed=1
    fi
  done
  return 0
}

verify_venv_bin_ascii() {
  local bindir="${1:?}"
  [[ -d "$bindir" ]] || return 0
  local f b bad=0
  for f in "$bindir"/*; do
    [[ -e "$f" ]] || continue
    b=$(basename "$f")
    if ! LC_ALL=C printf '%s' "$b" | grep -qE '^[!-~]+$'; then
      echo "错误: venv/bin 仍含非 ASCII 条目: $b" >&2
      bad=1
    fi
  done
  (( bad == 0 ))
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  sanitize_venv_bin "$1"
  verify_venv_bin_ascii "$1"
fi
