# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## Demo 视频

带配音的功能演示，覆盖系统音频采集、实时悬浮字幕、三层引擎（ASR → 句中翻译 → 句末润色）、观看场景、字幕记录与 Local/Cloud 变体等核心模块：

**[哔哩哔哩观看 →](https://space.bilibili.com/34746379)**

> **说明：** Demo 仅演示 **macOS 端**（本仓库 `releases/` 安装包与 `desktop/macos/`）。Windows 客户端在 `feat/winapp` 分支有初步实现，因时间有限未做充分测试与录制，故视频未包含 Windows 端。

## macOS

### 安装包试用

仓库 `[releases/](releases/)` 提供**未压缩**的 `.app`，无需解压 zip：


| 版本            | 路径                                                          | 体积      | 说明                      |
| ------------- | ----------------------------------------------------------- | ------- | ----------------------- |
| **Local**（推荐） | [VoiceBridgeAI-Local.app](releases/VoiceBridgeAI-Local.app) | ~1.2 GB | 内置 Whisper + Argos，离线可用 |
| **Cloud**     | [VoiceBridgeAI-Cloud.app](releases/VoiceBridgeAI-Cloud.app) | ~77 MB  | 仅云端 ASR/翻译              |


**获取方式（任选其一）**

```bash
# clone 后直接使用
git clone https://github.com/PPBrook/VoiceBridgeAI.git
open VoiceBridgeAI/releases/VoiceBridgeAI-Local.app   # 或 Cloud

# 只拉某一个 App（sparse checkout，省流量）
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.app   # 或 Cloud
git checkout
```

详细步骤与故障排查：[docs/submission.md](docs/submission.md)

**快速开始**

1. 将 `.app` 拖入「应用程序」，或 `cp -R releases/VoiceBridgeAI-*.app ~/Applications/`
2. **右键 → 打开**（未签名，首次不能双击）
3. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
4. 打开 App → **开始悬浮字幕**

### 源码开发

```bash
cp .env.example .env    # 首次
./run.sh                # 终端 1：Python 引擎
cd desktop/macos && ./run.sh   # 终端 2：Swift UI
```

详见 [docs/development.md](docs/development.md)。

### 构建独立 App

```bash
./run.sh                          # 确保仓库根 .venv 已创建
cd desktop/macos
./build-app-local.sh              # → dist/VoiceBridgeAI-Local.app
./build-app-cloud.sh              # → dist/VoiceBridgeAI-Cloud.app
```

产物在 `desktop/macos/dist/`（gitignore）。需要更新 `releases/` 供他人下载时，复制 `.app` 即可（**不要打 zip**），见 `scripts/publish-release.sh`。

---

## 文档


| 文档                                           | 内容              |
| -------------------------------------------- | --------------- |
| [docs/submission.md](docs/submission.md)     | 作品提交 / 评审说明     |
| [docs/development.md](docs/development.md)   | 本地开发、双终端启动、排错   |
| [docs/architecture.md](docs/architecture.md) | 数据流、引擎三层、App 变体 |
| [docs/README.md](docs/README.md)             | 文档索引            |
| [server/README.md](server/README.md)         | Python 引擎与 API  |
| [desktop/README.md](desktop/README.md)       | macOS 源码结构      |


