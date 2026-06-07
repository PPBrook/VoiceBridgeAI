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
| `core/` | `pcm`、`vad`、`revise`、`translate`（双引擎门面）、`local_models`、`llm_compat`、`http_errors` |
| `providers/` | `whisper_asr`、`tencent_asr`、`openai_asr`、`translate_*`、`provider_registry`、`provider_test` |

## 开发

```bash
# 在仓库根目录
./run.sh
# 等价于 cd server && python main.py
```

数据目录（开发）：仓库根目录（须含 `run.sh` 与 `server/main.py`）。  
生产 / App：`~/Library/Application Support/VoiceBridgeAI/`（`.env`、`cloud-ui.json`、`models/`、`server.log`）。

## 主要 API

见根目录 [README](../README.md#api节选)。
