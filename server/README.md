# Python 引擎（Sidecar）

FastAPI + WebSocket，负责 ASR、句中翻译、句末润色与配置 API。开发时由仓库根目录 `run.sh` 启动；打包后由 App 内置 `run-server.sh` 启动。

## 目录

```
server/
  main.py              入口（创建 app，uvicorn）
  app_bootstrap.py     环境变量、lifespan、启动测试、模型预加载
  routes/              HTTP / WebSocket 路由
  config/              引擎与云端配置、.env 持久化、UI 偏好
  core/                PCM、VAD、翻译调度、本地模型、修订、LLM 提示
  providers/           各厂商 ASR / 翻译实现与连通性测试
```

### routes/

| 模块 | 职责 |
|------|------|
| `health.py` | `/`、`/api/health` |
| `models_local.py` | 本地模型下载 / 删除 / 设置 |
| `cloud.py` | 云端密钥、测试、UI 偏好 |
| `engine.py` | 引擎 / ASR / 翻译设置 |
| `ws.py` | WebSocket PCM 会话 |
| `__init__.py` | `register_routes(app)` |

### config/

| 模块 | 职责 |
|------|------|
| `app_paths.py` | 开发 / App 数据目录解析 |
| `env_persist.py` | `.env` 读写映射 |
| `asr_config.py` | ASR 模式与状态 |
| `partial_config.py` | 句中翻译 provider |
| `final_config.py` | 句末润色 provider |
| `engine_config.py` | 三层引擎聚合状态 |
| `revise_config.py` | 观看场景预设（VAD + 润色提示） |
| `cloud_config.py` | 云端密钥持久化 |
| `cloud_ui_prefs.py` | `cloud-ui.json` 卡片隐藏 |

### core/

| 模块 | 职责 |
|------|------|
| `pcm.py` | 重采样、缓冲、分帧 |
| `vad.py` | 静音 VAD 断句 |
| `revise.py` | 句中/句末调度、回溯纠正 |
| `revise_context.py` | 当前观看场景上下文 |
| `translate.py` | partial/final 路由与缓存 |
| `llm_compat.py` | LLM 润色提示与 OpenAI 兼容请求 |
| `local_models.py` | 本地模型门面（兼容 import） |
| `local_models_catalog.py` | 目录常量与开关 |
| `local_models_paths.py` | 路径与 marker |
| `local_models_whisper.py` | Whisper 下载/卸载 |
| `local_models_argos.py` | Argos 下载/卸载 |
| `local_models_api.py` | 状态、设置、调度 |
| `local_model_jobs.py` | 后台下载任务 |
| `local_model_messages.py` | 下载进度文案 |
| `http_errors.py` | HTTP 错误格式化 |

### providers/

| 类型 | 模块 |
|------|------|
| ASR | `whisper_asr`、`tencent_asr`、`openai_asr` |
| MT | `translate_tmt`、`translate_baidu`、`translate_deepl`、`translate_argos`、`translate_google`（经 config） |
| LLM | `translate_qiniu`、`translate_aliyun`、`translate_deepseek`、`translate_openai`（共用 `llm_openai_compat.py`） |
| 其它 | `provider_registry`、`provider_enable`、`provider_test` |

## 开发

```bash
# 在仓库根目录
./run.sh
```

数据目录（开发）：仓库根（须含 `run.sh` 与 `server/main.py`）。  
生产 / App：`~/Library/Application Support/VoiceBridgeAI/`（`.env`、`cloud-ui.json`、`models/`、`server.log`）。

## 主要 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查、引擎与本地模型状态 |
| GET | `/api/models/local` | 本地模型状态 |
| POST | `/api/models/local/download` | 后台下载，立即返回 `job` |
| GET | `/api/models/local/download/{jobId}` | 下载进度与状态 |
| POST | `/api/models/local/delete` | 删除已下载模型 |
| POST | `/api/models/local/settings` | 启用/切换 Whisper、Argos |
| POST | `/api/engine/settings` | 保存 ASR / 翻译 / 观看场景 |
| POST | `/api/cloud/settings` | 保存云端密钥 |
| POST | `/api/cloud/test` | 单接口连通性测试 |
| WS | `/ws` | config + PCM → 字幕事件 |

### 观看场景 `REVISE_MODE`

| 值 | 说明 |
|----|------|
| `speech` | 演讲 · 跟节奏（默认） |
| `tech` | 技术分享 · 术语稳定 |
| `conference` | 会议 · 低延迟 |
| `course` | 网课 · 知识点整段 |

旧值映射：`balanced`→`speech`，`speed`→`conference`，`accuracy`→`course`。

`GET /api/health` 返回 `reviseModes`（含 `description`、`polishNote`、`examples`、断句参数）与 `reviseSceneNote`。

开发流程见 [docs/development.md](../docs/development.md)。
