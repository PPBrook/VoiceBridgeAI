# Python 引擎（server/）

FastAPI + WebSocket：ASR、句中/句末翻译、纠正、云端配置、本地模型下载。

桌面 App 与（归档）浏览器扩展 **共用本目录**。

## 启动

```bash
# 仓库根
./run.sh
# 或
cd server && python main.py
```

独立 App 由 `desktop/macos/scripts/run-server.sh` 在 bundle 内启动，无需手动执行。

## 配置

| 模式 | `.env` 位置 |
|------|----------------|
| 开发 | 仓库根 `.env` |
| 独立 App | `~/Library/Application Support/VoiceBridgeAI/.env` |

路径逻辑：`app_paths.py`（`VOICEBRIDGE_DATA_DIR`）。

## 主要模块

| 文件 | 作用 |
|------|------|
| `main.py` | FastAPI、WebSocket、静态页（开发） |
| `local_models.py` | Whisper/Argos 按需下载 |
| `app_paths.py` | 开发 / bundled 路径 |
| `env_persist.py` | 设置写入 `.env` |
| `provider_registry.py` | 引擎 ID 与组合规则 |
| `provider_enable.py` | 测试门控、本地模型安装检测 |
| `whisper_asr.py` | 本地 ASR |
| `translate_*.py` | 各厂商翻译/ASR 适配 |
| `vad.py` / `revise*.py` | 分句与纠正 |

## HTTP API（节选）

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康、引擎、本地模型、startupTest |
| GET | `/api/models/local` | 本地模型状态 |
| POST | `/api/models/local/download` | 下载 Whisper / Argos |
| POST | `/api/engine/settings` | 保存引擎 |
| POST | `/api/cloud/settings` | 保存云端密钥 |
| WS | `/ws` | PCM 音频流 |

协议细节：[docs/websocket-api.md](../docs/websocket-api.md)。

## 环境变量

见仓库根 `.env.example`。桌面默认：

- `VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=1` — 本地模型须先下载
- `AUTO_TEST_ON_START=0` — App 内可设为 0 加快冷启动
