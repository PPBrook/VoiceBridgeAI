# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## Demo 视频

带配音的功能演示，覆盖系统音频采集、实时悬浮字幕、三层引擎（ASR → 句中翻译 → 句末润色）、观看场景、字幕记录与 Local/Cloud 变体：

| 平台 | 链接 | 状态 |
|------|------|------|
| **哔哩哔哩** | [澎湃brooks 空间](https://space.bilibili.com/34746379) | **审核中**（通过后更新 BV 链接） |
| **备用（仓库内，可直接播放）** | [VoiceBridgeAI-demo.mp4](docs/demo/VoiceBridgeAI-demo.mp4) | 可用 |

GitHub 上点击 mp4 链接即可在线播放；clone 后也可本地打开 `docs/demo/VoiceBridgeAI-demo.mp4`。

> Demo 仅演示 **macOS 端**。Windows 客户端在 `feat/winapp` 分支有初步实现，因时间有限未做充分测试与录制。

## 安装试用

仓库 [`releases/`](releases/) 提供未压缩 `.app`：

| 版本 | 路径 | 体积 | 说明 |
|------|------|------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.app](releases/VoiceBridgeAI-Local.app) | ~1.2 GB | 内置 Whisper + Argos，离线可用 |
| **Cloud** | [VoiceBridgeAI-Cloud.app](releases/VoiceBridgeAI-Cloud.app) | ~77 MB | 仅云端 ASR/翻译 |

```bash
git clone https://github.com/PPBrook/VoiceBridgeAI.git
open VoiceBridgeAI/releases/VoiceBridgeAI-Local.app
```

只拉单个 App：`git sparse-checkout set releases/VoiceBridgeAI-Local.app`

**快速开始：** 拖入「应用程序」→ **右键 → 打开** → 授予**屏幕录制** → **开始悬浮字幕**

详细步骤与故障排查：[docs/submission.md](docs/submission.md)

## 源码开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

构建独立 App：`desktop/macos/build-app-{local,cloud}.sh` → `dist/`；发布到 `releases/` 见 `scripts/publish-release.sh`。

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 评审 / 试用说明 |
| [docs/development.md](docs/development.md) | 开发流程与排错 |
| [docs/architecture.md](docs/architecture.md) | 架构与数据流 |
| [server/README.md](server/README.md) | Python 引擎 API |
| [desktop/README.md](desktop/README.md) | macOS 构建 |

完整索引：[docs/README.md](docs/README.md)
