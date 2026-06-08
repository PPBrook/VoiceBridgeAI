# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## 项目介绍

看英文视频、技术分享、会议或网课时，往往听不全或来不及查词。VoiceBridgeAI 采集**系统播放的英文音频**，经 **ASR → 句中翻译 → 句末润色** 三层引擎，在屏幕上方显示**实时中文悬浮字幕**；支持观看场景切换、字幕记录导出与透明度调节。

项目从 **Web 控制台 + 浏览器扩展**（[`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only)）演进为 macOS 原生 App（`main`），并探索 Windows 客户端（[`feat/winapp`](https://github.com/PPBrook/VoiceBridgeAI/tree/feat/winapp)）。当前提交以 **macOS 独立安装包** 为主。

**技术栈：** Swift / AppKit / ScreenCaptureKit（客户端）· Python / FastAPI / WebSocket（引擎侧车）· Whisper、Argos（本地）· 腾讯 / OpenAI 等（云端可选）

## Demo 视频

**[哔哩哔哩观看 →](https://www.bilibili.com/video/BV1C4Et6PESe/)**

带配音演示：系统音频采集、悬浮字幕、三层引擎（ASR → 句中翻译 → 句末润色）、观看场景、字幕记录、Local/Cloud 变体。

> Demo 仅 **macOS 端**（`main`）。其它平台见下方分支说明。

## 项目演进与其它分支

`main` 是当前提交评审的 **macOS 原生 App**。更早与并行的探索保留在下列分支：

| 分支 | 形态 | 说明 | 状态 |
|------|------|------|------|
| [`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only) | Web 控制台 + Chromium 扩展 | 最早原型：浏览器标签页英文 → 悬浮字幕；支持 **语音识别** 与 **YouTube 英文字幕** 两条输入（扩展抓取 CC，跳过 ASR） | 历史版本，功能已不在 `main` 维护 |
| [`feat/winapp`](https://github.com/PPBrook/VoiceBridgeAI/tree/feat/winapp) | Windows 原生客户端 | C# / WinUI 3 + WASAPI 系统环回采音，复用同一 `server/` 引擎与 WebSocket 协议；含托盘、悬浮字幕、设置窗等 | 初步实现，未充分测试，**未纳入 Demo** |

```bash
git fetch origin
git checkout legacy/web-only   # Web + 扩展
git checkout feat/winapp       # Windows 客户端（另需 .\run.ps1）
git checkout main              # 回到 macOS 正式版
```

## 逾期提交说明

截止前时间管理不足，安装包「下载后无法打开」的问题在多次提交中反复出现；最后一次提交时**未在干净环境完整走通「下载 → 解压 → 打开」**，评审侧可能因此无法正常试用。

事后排查确认：**多数「已损坏，无法打开」并非 zip 损坏**，而是 macOS **Gatekeeper 隔离标记**（`xattr -cr` 即可）。此前误判为解压方式或打包问题，反复改 zip 与文档，反而耽误了定位根因。

本次逾期改动：补充正确的打开步骤（见下）、重新校验安装包，并对给评审带来的不便深表歉意。

## 安装试用

[`releases/`](releases/) 提供 zip 安装包（Git LFS）：

| 版本 | 文件 | 体积（zip / 解压后） | 说明 |
|------|------|----------------------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | ~430 MB / ~1.1 GB | 内置 Whisper + Argos，离线可用 |
| **Cloud** | [VoiceBridgeAI-Cloud.zip](releases/VoiceBridgeAI-Cloud.zip) | ~26 MB / ~70 MB | 仅云端 ASR/翻译 |

**评审推荐 Local：** 内置 Whisper + Argos，**开箱离线可用**，无需配置 API Key 或下载模型。Cloud 体积更小，但需在 App 设置页填写云端密钥，且无本地模型 Tab。

**系统要求：** macOS 13+

### 快速开始

```bash
git clone https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git lfs pull --include="releases/VoiceBridgeAI-Local.zip"   # Local；Cloud 改对应文件名

ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
open VoiceBridgeAI-Local.app    # 首次请右键 → 打开
```

1. **解压** zip（`ditto`、unzip 或 Finder 均可）
2. **`xattr -cr` .app** → **右键 → 打开**（App 未签名，首次不能双击）
3. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
4. 播放英文系统音频 → **开始悬浮字幕**

### 提示「已损坏，无法打开」？

**通常不是文件损坏**，而是 macOS **Gatekeeper** 对下载内容附加的隔离标记。对 `.app` 执行：

```bash
xattr -cr VoiceBridgeAI-Local.app
# 或：xattr -cr ~/Downloads/VoiceBridgeAI-Cloud.app
```

然后 **右键 → 打开**。

### 只下载 zip（sparse checkout）

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout init --no-cone
git sparse-checkout set /releases/VoiceBridgeAI-Local.zip
git checkout
git lfs pull --include="releases/VoiceBridgeAI-Local.zip"

ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
```

- zip 仅几 KB → 未拉 LFS，执行 `git lfs pull --include=…`
- Local zip 远小于 **~400 MB** → 文件不完整，重新 pull（完整 zip 约 430 MB，解压后 ~1.1 GB）
- sparse 报 `is not a directory` → 须 `init --no-cone` 且路径写 `/releases/….zip`

更多故障排查：[docs/submission.md](docs/submission.md)

## 源码开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

构建独立 App：`desktop/macos/build-app-{local,cloud}.sh` → `dist/`；发布 zip 见 `desktop/macos/scripts/publish-release.sh`。

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 评审 / 试用说明 |
| [docs/development.md](docs/development.md) | 开发流程与排错 |
| [docs/architecture.md](docs/architecture.md) | 架构与数据流 |
| [server/README.md](server/README.md) | Python 引擎 API |
| [desktop/README.md](desktop/README.md) | macOS 构建 |

完整索引：[docs/README.md](docs/README.md)
