# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## Demo 视频

带配音的功能演示，覆盖系统音频采集、实时悬浮字幕、三层引擎（ASR → 句中翻译 → 句末润色）、观看场景、字幕记录与 Local/Cloud 变体：

**[哔哩哔哩观看 →](https://www.bilibili.com/video/BV1C4Et6PESe/)**

> Demo 仅演示 **macOS 端**。Windows 客户端在 `feat/winapp` 分支有初步实现，因时间有限未做充分测试与录制。

## 安装试用

仓库 [`releases/`](releases/) 提供 **zip 打包安装包**（Git LFS）：

| 版本 | 文件 | 体积 | 说明 |
|------|------|------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | ~1.2 GB | 内置 Whisper + Argos，离线可用 |
| **Cloud** | [VoiceBridgeAI-Cloud.zip](releases/VoiceBridgeAI-Cloud.zip) | ~70 MB | 仅云端 ASR/翻译 |

### ⚠️ 必须用终端解压（勿双击 zip）

> **Finder /「归档实用工具」双击解压，大概率导致 `.app` 损坏**（提示「已损坏，无法打开」）。**请务必在终端执行以下命令。**  
> 若 zip 体积明显偏小（Local 应约 **1.2 GB**），说明文件不完整或 LFS 未拉取，请 `git lfs pull` 或重新 clone。

```bash
git clone https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git lfs pull    # 必须：否则 zip 只有几 KB 的 LFS 指针

# 必须：终端解压（推荐 ditto）
ditto -xk releases/VoiceBridgeAI-Local.zip .
# Cloud 版：ditto -xk releases/VoiceBridgeAI-Cloud.zip .

xattr -cr VoiceBridgeAI-Local.app
open VoiceBridgeAI-Local.app
```

**禁止：** 在 Finder 中双击 zip、拖入「归档实用工具」解压。  
**备选：** `unzip -q releases/VoiceBridgeAI-Local.zip`（解压后同样执行 `xattr -cr`）。

只拉 zip（sparse checkout）：

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.zip
git checkout
git lfs pull
ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
```

**快速开始：** 终端解压 → `xattr -cr` → **右键 → 打开** App → 授予**屏幕录制** → **开始悬浮字幕**

详细步骤与故障排查：[docs/submission.md](docs/submission.md)

## 源码开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

构建独立 App：`desktop/macos/build-app-{local,cloud}.sh` → `dist/`；打包发布见 `scripts/publish-release.sh`。

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 评审 / 试用说明 |
| [docs/development.md](docs/development.md) | 开发流程与排错 |
| [docs/architecture.md](docs/architecture.md) | 架构与数据流 |
| [server/README.md](server/README.md) | Python 引擎 API |
| [desktop/README.md](desktop/README.md) | macOS 构建 |

完整索引：[docs/README.md](docs/README.md)
