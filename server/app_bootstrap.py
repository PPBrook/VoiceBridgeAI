"""Application startup: env, lifespan, provider preload, startup tests."""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI

from config.app_paths import env_file_path
from config.asr_config import default_mode, normalize_mode
from providers.whisper_asr import load_model as load_whisper
import core.local_models as local_models
from config.cloud_config import test_all_and_verify

log = logging.getLogger(__name__)

FEATURES = [
    "health-api",
    "websocket-pcm",
    "asr-multi",
    "translate-dual-engine",
    "cloud-config",
    "local-models-optional",
    "subtitle-revise",
]

_startup_test: dict = {"running": False, "done": False, "summary": None, "results": []}


def load_env_file() -> None:
    env_path = env_file_path()
    if not env_path.is_file():
        return
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'\"")
        if key and key not in os.environ:
            os.environ[key] = value


def startup_test_status() -> dict:
    return dict(_startup_test)


async def preload_translate(payload: dict | None = None) -> None:
    from config.final_config import normalize_provider as normalize_final
    from config.partial_config import normalize_provider as normalize_partial

    partial = normalize_partial(payload.get("partialProvider") if payload else None)
    final = normalize_final(payload.get("finalProvider") if payload else None)
    if partial == "argos" or final == "argos":
        if not local_models.optional_local_models_enabled() or local_models.is_argos_installed():
            from providers.translate_argos import load_model as load_argos

            await asyncio.to_thread(load_argos)


async def preload_after_provider_test(layer: str, provider_id: str) -> None:
    if layer == "asr" and provider_id == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
        return
    if layer in ("partial", "final") and provider_id == "argos":
        if not local_models.optional_local_models_enabled() or local_models.is_argos_installed():
            from providers.translate_argos import load_model

            await asyncio.to_thread(load_model)


async def run_startup_tests() -> None:
    global _startup_test
    if os.getenv("AUTO_TEST_ON_START", "1").strip().lower() in ("0", "false", "no", "off"):
        _startup_test = {
            "running": False,
            "done": True,
            "summary": "已跳过启动测试（AUTO_TEST_ON_START=0）",
            "results": [],
        }
        return
    _startup_test = {
        "running": True,
        "done": False,
        "summary": "正在测试已配置且未隐藏的接口…",
        "results": [],
    }
    try:
        results, summary = await asyncio.to_thread(test_all_and_verify, None)
        for item in results:
            if item.get("ok"):
                await preload_after_provider_test(
                    str(item["layer"]),
                    str(item["providerId"]),
                )
        _startup_test = {
            "running": False,
            "done": True,
            "summary": summary,
            "results": results,
        }
        log.info("startup test-all: %s", summary)
    except Exception:
        log.exception("startup test-all failed")
        _startup_test = {
            "running": False,
            "done": True,
            "summary": "启动测试异常",
            "results": [],
        }


@asynccontextmanager
async def lifespan(_app: FastAPI):
    mode = normalize_mode(default_mode())
    log.info("default ASR mode: %s", mode)
    if mode == "local":
        if not local_models.optional_local_models_enabled() or local_models.is_whisper_installed():
            await asyncio.to_thread(load_whisper)
    startup_task = asyncio.create_task(run_startup_tests())
    yield
    startup_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await startup_task


def create_app() -> FastAPI:
    load_env_file()
    logging.basicConfig(level=logging.INFO)
    app = FastAPI(title="VoiceBridgeAI", version="0.1.0", lifespan=lifespan)
    from routes import register_routes

    register_routes(app)
    return app
