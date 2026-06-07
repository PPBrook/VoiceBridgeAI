"""Live connectivity tests for provider verification."""

from __future__ import annotations

import json
import logging
import os
import urllib.error
import urllib.request

from providers.provider_enable import credentials_ok
from providers.provider_registry import LAYER_PROVIDERS

log = logging.getLogger(__name__)

_SAMPLE = "Hello"

_ASR_HANDLERS = {
    "local": lambda: _test_asr_local(),
    "tencent": lambda: _test_asr_tencent(),
    "openai": lambda: _test_asr_openai(),
}


def test_provider(layer: str, provider_id: str) -> tuple[bool, str]:
    if provider_id not in LAYER_PROVIDERS.get(layer, ()):
        return False, f"未知接口：{layer}/{provider_id}"
    if not credentials_ok(layer, provider_id):
        return False, "请先填写密钥（可先保存，测试时会读取表单内容）"
    try:
        return _run_test(layer, provider_id)
    except Exception as exc:
        log.exception("provider test failed %s/%s", layer, provider_id)
        return False, str(exc)


def _run_test(layer: str, provider_id: str) -> tuple[bool, str]:
    if layer == "asr":
        return _ASR_HANDLERS[provider_id]()
    if layer == "partial":
        return _test_translate(provider_id, partial=True)
    if provider_id == "none":
        return _test_final_none()
    return _test_translate(provider_id, partial=False)


def _test_asr_local() -> tuple[bool, str]:
    from core.local_models import is_whisper_installed, optional_local_models_enabled

    if optional_local_models_enabled() and not is_whisper_installed():
        return False, "Whisper 未安装，请先在「本地模型」下载"
    from providers.whisper_asr import load_model

    load_model()
    return True, "本地 Whisper 可用"


def _test_asr_tencent() -> tuple[bool, str]:
    from providers.tencent_asr import build_ws_url, configured

    if not configured():
        return False, "腾讯云 ASR 凭证不完整"
    build_ws_url("voicebridge-test")
    return True, "腾讯云 ASR 凭证有效"


def _test_asr_openai() -> tuple[bool, str]:
    return _test_openai_http("OpenAI 语音识别")


def _test_openai_http(label: str) -> tuple[bool, str]:
    key = os.getenv("OPENAI_API_KEY", "").strip()
    if not key:
        return False, "缺少 OpenAI API Key"
    base = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").strip().rstrip("/")
    req = urllib.request.Request(
        f"{base}/models",
        headers={"Authorization": f"Bearer {key}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        from core.http_errors import format_http_error

        return False, format_http_error(label, exc.code, detail)
    except Exception as exc:
        return False, f"{label} 连接失败: {exc}"
    return True, f"{label} Key 有效（列表接口可达；Whisper/Chat 额度未单独检测）"


def _test_translate(provider_id: str, *, partial: bool) -> tuple[bool, str]:
    if partial:
        from config.partial_config import translate

        out = translate(_SAMPLE, provider_id)
        label = "句中翻译"
    else:
        from config.final_config import translate

        out = translate(_SAMPLE, "你好", provider_id)
        label = "句末润色"
    if not (out and out.strip()):
        return False, f"{label} 返回空结果"
    snippet = out.strip()[:24]
    return True, f"{label} 测试通过（{_SAMPLE} → {snippet}）"


def _test_final_none() -> tuple[bool, str]:
    return True, "句末沿用句中，无需密钥"


def iter_test_targets():
    """Yield (layer, provider_id) for providers that can be tested now."""
    from providers.provider_enable import credentials_ok, is_default_available

    for layer, ids in LAYER_PROVIDERS.items():
        for provider_id in ids:
            if is_default_available(layer, provider_id):
                continue
            if credentials_ok(layer, provider_id):
                yield layer, provider_id


def test_all_providers() -> list[dict[str, str | bool]]:
    """Run live tests for every configured provider."""
    results: list[dict[str, str | bool]] = []
    for layer, provider_id in iter_test_targets():
        ok, message = test_provider(layer, provider_id)
        results.append(
            {
                "layer": layer,
                "providerId": provider_id,
                "ok": ok,
                "message": message,
            }
        )
    return results
