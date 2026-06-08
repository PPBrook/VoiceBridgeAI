# 开发指南

## 日常流程（两个终端）

```bash
# 终端 1 — 引擎（仓库根）
cp .env.example .env              # 首次
./run.sh

# 终端 2 — Swift UI
cd desktop/macos && ./run.sh
```

改 Python 后重启终端 1；改 Swift 后重启终端 2（自动重新编译）。

## 仓库结构

```
VoiceBridgeAI/
  run.sh, requirements*.txt, .env.example
  server/          Python 侧车
  desktop/macos/   Swift App
  releases/        安装包 zip（Git LFS）
  docs/
```

主分支维护 **macOS App + Python 引擎**。其它形态见 [`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only)（Web + 扩展）、[`feat/winapp`](https://github.com/PPBrook/VoiceBridgeAI/tree/feat/winapp)（Windows）；概述见 [README](../README.md#项目演进与其它分支)。

## 数据目录

| 内容 | 开发（`./run.sh`） | 独立 App |
|------|-------------------|----------|
| `.env` / `cloud-ui.json` | 仓库根 | Application Support |
| `models/` / `transcripts/` | 仓库根 | Application Support 或 `bundled-models/` |
| 日志 | — | Application Support |

Application Support 目录：`VoiceBridgeAI/`（开发）、`VoiceBridgeAI-Cloud/`、`VoiceBridgeAI-Local/`。

## 界面行为

| 位置 | 行为 |
|------|------|
| 主窗口 × / − | 退出 / 收起到菜单栏 |
| 观看场景 | 主窗口或设置 → 引擎；运行中热更新 |
| ASR/翻译 | 更换 provider 需停止再开始 |
| 悬浮 · 记 / 背景/文字 | 字幕记录开关、透明度 |
| 静音 ~2.5s | 清空悬浮字幕（会话不中断） |

字幕记录形式：中英对照（分区）、中英结合（连续）、纯英文、纯中文。

## 本地模型

Whisper 权重在 `models/hf/hub/`，标记在 `models/whisper/.installed-{规格}`。Argos 标记在 `models/argos/.installed-en-zh`。

设置页 API：`POST /api/models/local/download`、`GET .../download/{jobId}`、`POST .../settings`、`POST .../delete`。完整列表见 [server/README.md](../server/README.md)。

## 故障排查

```bash
# 端口占用
kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)
./run.sh
```

改代码后行为不对 → 重启对应终端。本地模型状态异常 → 重启引擎。

架构与观看场景参数见 [architecture.md](architecture.md)。
