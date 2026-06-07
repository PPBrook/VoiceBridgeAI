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

配置目录：`~/Library/Application Support/VoiceBridgeAI/`（`.env`、`server.log`、`models/`、`transcripts/`）

主窗口：**×** 退出 App；**−** 收起到菜单栏。

## 开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

详细说明：[docs/development.md](docs/development.md)

## 结构

```
VoiceBridgeAI/
  run.sh                 开发启动引擎
  requirements.txt
  server/                FastAPI 引擎（见 server/README.md）
  desktop/macos/         Swift App（见 desktop/README.md）
  docs/                  架构与开发说明（见 docs/README.md）
```

App bundle：`Contents/Resources/{server, python-venv, run-server.sh}`

更多细节：[docs/architecture.md](docs/architecture.md)

## 架构

```
ScreenCaptureKit → Swift App → ws://127.0.0.1:8765/ws → server/ → 字幕 overlay
```

三层引擎：ASR（Whisper / 腾讯 / OpenAI）→ 句中翻译 → 句末润色。本地模型须在 App 内下载。

**观看场景**（主窗口或设置 → 引擎）：演讲 / 技术分享 / 会议 / 网课 — 影响断句节奏与 LLM 润色风格。字幕运行中切换即时生效；更换 ASR 或翻译接口需停止再开始。

**悬浮字幕**：顶栏可调背景/文字透明度、英文显示、观看场景标签；暂停约 2.5s 自动清空旧句。**字幕记录**（设置 → 字幕记录）：定稿句写入 `transcripts/`，可选纯英/纯中/中英对照等形式，并支持转换已有文件。

## API（节选）

| 路径 | 说明 |
|------|------|
| GET `/api/health` | 状态、引擎、本地模型 |
| POST `/api/models/local/download` | 下载 Whisper / Argos |
| POST `/api/models/local/delete` | 删除已下载模型 |
| POST `/api/models/local/settings` | 启用/关闭、切换 Whisper 规格 |
| POST `/api/engine/settings` | 保存引擎 |
| POST `/api/cloud/settings` | 保存密钥 |
| WS `/ws` | config + PCM → asr / asrReady |

## 故障排查

| 现象 | 处理 |
|------|------|
| 启动失败 | `~/Library/Application Support/VoiceBridgeAI/server.log` |
| 无 Whisper/Argos | 设置 → 本地模型 |
| 无声音 | 屏幕录制权限 |
| 端口占用 | 终端 `Ctrl+C`，或 `kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)` |
| 暂停后旧字幕不消失 | 确认已更新 App；静音约 2.5s 会自动清空 |

## 限制

未签名、约 0.9GB（含 Python 依赖）、仅本机、无 YouTube CC。
