# Python 引擎（Sidecar）

FastAPI + WebSocket：ASR、句中翻译、句末润色与配置 API。开发时由仓库根 `run.sh` 启动；打包后由 App 内 `run-server.sh` 启动。

## 目录

```
server/
  main.py, app_bootstrap.py
  routes/       health, models_local, cloud, engine, ws
  config/       引擎/云端配置、.env 持久化、观看场景
  core/         PCM、VAD、翻译调度、修订、本地模型
  providers/    各厂商 ASR / 翻译 / 连通性测试
```

## 主要 API

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/health` | 健康检查、引擎与本地模型状态 |
| POST | `/api/models/local/download` | 后台下载 Whisper / Argos |
| GET | `/api/models/local/download/{jobId}` | 下载进度 |
| POST | `/api/models/local/settings` | 启用/切换本地模型 |
| POST | `/api/models/local/delete` | 删除已下载模型 |
| POST | `/api/engine/settings` | ASR / 翻译 / 观看场景 |
| POST | `/api/cloud/settings` | 云端密钥 |
| POST | `/api/cloud/test` | 连通性测试 |
| WS | `/ws` | config + PCM → 字幕事件 |

## 开发

```bash
# 仓库根
./run.sh
```

数据目录：开发时在仓库根；App 时在 `~/Library/Application Support/VoiceBridgeAI{,-Cloud,-Local}/`。

架构与观看场景见 [docs/architecture.md](../docs/architecture.md)。日常开发见 [docs/development.md](../docs/development.md)。
