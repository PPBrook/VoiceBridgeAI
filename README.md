# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。Swift UI + 内置 Python 引擎。

浏览器版备份分支：`legacy/web-only`

## 安装使用

```bash
cd desktop/macos
./build-app.sh
open dist/VoiceBridgeAI.app
```

1. **屏幕录制**权限（系统设置 → 隐私与安全性）
2. App **设置 → 本地模型** 下载 Whisper/Argos，或 **接口密钥** 配云端
3. **开始悬浮字幕**

配置目录：`~/Library/Application Support/VoiceBridgeAI/`（`.env`、`server.log`、`models/`）

## 开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

仅调试 UI：`SKIP_VENV=1 ./build-app.sh`（不能独立运行）

## 结构

```
desktop/macos/     Swift App（见 desktop/README.md）
server/            FastAPI 引擎（见 server/README.md）
docs/              架构说明
run.sh             开发时启动引擎
```

App bundle：`Contents/Resources/{server, python-venv, run-server.sh}`

更多细节：[docs/architecture.md](docs/architecture.md)

## 架构

```
ScreenCaptureKit → Swift App → ws://127.0.0.1:8765/ws → server/ → 字幕 overlay
```

三层引擎：ASR（Whisper / 腾讯 / OpenAI）→ 句中翻译 → 句末润色。本地模型默认须 App 内下载（`VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=1`）。

## API（节选）

| 路径 | 说明 |
|------|------|
| GET `/api/health` | 状态、引擎、本地模型 |
| POST `/api/models/local/download` | 下载 Whisper / Argos |
| POST `/api/engine/settings` | 保存引擎 |
| POST `/api/cloud/settings` | 保存密钥 |
| WS `/ws` | config + PCM → asr / asrReady |

## 故障排查

| 现象 | 处理 |
|------|------|
| 启动失败 | `~/Library/Application Support/VoiceBridgeAI/server.log` |
| 无 Whisper/Argos | 设置 → 本地模型 |
| 无声音 | 屏幕录制权限 |
| 端口占用 | `kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)` |

## 限制

未签名、约 0.9GB（含 Python 依赖）、仅本机、无 YouTube CC。
