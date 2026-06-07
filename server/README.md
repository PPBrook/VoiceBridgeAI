# Python 引擎（Sidecar）

FastAPI + WebSocket，负责 ASR、句中翻译、句末润色与配置 API。开发时由仓库根目录 `run.sh` 启动；打包后由 App 内置 `run-server.sh` 启动。

## 目录

```
server/
  main.py           HTTP / WebSocket 入口
  config/           引擎与云端配置、.env 持久化、UI 偏好
  core/             PCM、VAD、翻译调度、本地模型、修订
  providers/        各厂商 ASR / 翻译实现与连通性测试
```

| 包 | 职责 |
|----|------|
| `config/` | `asr_config`、`partial_config`、`final_config`、`engine_config`、`cloud_config`、`cloud_ui_prefs`、`env_persist`、`app_paths` |
| `core/` | `pcm`、`vad`、`revise`、`translate`、`local_models`、`llm_compat`、`http_errors` |
| `providers/` | `whisper_asr`、`tencent_asr`、`openai_asr`、`translate_*`、`provider_registry`、`provider_test`、`provider_enable` |

## 开发

```bash
# 在仓库根目录
./run.sh
# 等价于 cd server && python main.py
```

数据目录（开发）：仓库根目录（须含 `run.sh` 与 `server/main.py`）。  
生产 / App：`~/Library/Application Support/VoiceBridgeAI/`（`.env`、`cloud-ui.json`、`models/`、`server.log`）。

## 主要 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查、引擎与本地模型状态 |
| GET | `/api/models/local` | 本地模型状态 |
| POST | `/api/models/local/download` | `{ id: whisper\|argos, whisperModel? }` |
| POST | `/api/models/local/delete` | `{ id: whisper\|argos, whisperModel? }` 删除已下载文件 |
| POST | `/api/models/local/settings` | 见下表 |
| POST | `/api/engine/settings` | 保存 ASR / 翻译引擎选择 |
| POST | `/api/cloud/settings` | 保存云端密钥 |
| POST | `/api/cloud/test` | 单接口连通性测试 |
| WS | `/ws` | 音频流与字幕 |

### `/api/models/local/settings` 字段

| 字段 | 说明 |
|------|------|
| `whisperEnabled` | 启用/关闭 Whisper |
| `argosEnabled` | 启用/关闭 Argos |
| `action` | `"switch"` 时切换 Whisper |
| `whisperModel` | 目标规格，如 `tiny.en` |

本地模型逻辑见 `core/local_models.py`（marker、HF 缓存、Argos 包目录）。

开发流程见 [docs/development.md](../docs/development.md)。
