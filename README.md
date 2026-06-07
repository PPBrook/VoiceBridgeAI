# VoiceBridgeAI

系统英文音频 → 实时中文悬浮字幕。  
**macOS** 原生 App（主分支 + 评审安装包）；**Windows** WinUI 客户端（`feat/winapp`，功能已对齐）。

## macOS

### 安装包试用

| 版本 | 获取方式 | 体积 | 说明 |
|------|----------|------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | ~428 MB | 内置 Whisper + Argos，离线可用（Git LFS） |
| **Cloud** | [releases/VoiceBridgeAI-Cloud.app](releases/VoiceBridgeAI-Cloud.app) | ~77 MB | 仅云端 ASR/翻译，**不压缩**，无需解压 |

**Local**：GitHub 下载 zip → 解压。**Cloud**：clone 或 sparse-checkout 后直接使用 `.app`（见 [docs/submission.md](docs/submission.md)）。

**快速开始**

1. **右键打开** 对应 `.app`（未签名，首次不能双击）
2. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
3. 打开 App → **开始悬浮字幕**（播放含英文的系统音频，如浏览器视频）

配置与日志：`~/Library/Application Support/VoiceBridgeAI-Local/` 或 `VoiceBridgeAI-Cloud/`。

**详细说明**（下载方式、内置功能、故障排查、作品介绍）：[docs/submission.md](docs/submission.md)

### 源码开发

```bash
cp .env.example .env    # 首次；或直接使用仓库中的 .env
./run.sh                # 终端 1：Python 引擎
cd desktop/macos && ./run.sh   # 终端 2：Swift UI
```

### 打包独立 App

```bash
./run.sh                          # 确保仓库根 .venv 已创建
cd desktop/macos
./build-app-local.sh              # → dist/VoiceBridgeAI-Local.app
./build-app-cloud.sh              # → dist/VoiceBridgeAI-Cloud.app
./scripts/package-release-zip.sh local   # → releases/VoiceBridgeAI-Local.zip
./scripts/package-release-zip.sh cloud   # → releases/VoiceBridgeAI-Cloud.app（直接复制）
```

产物在 `desktop/macos/dist/`（gitignore）。Local 发布 zip 在 `releases/`（Git LFS）；Cloud 为 `releases/VoiceBridgeAI-Cloud.app/` 目录。

## Windows

WinUI 3 客户端在 `feat/winapp` 分支开发，设置窗与 macOS 对齐（引擎 / 本地模型 / 字幕记录 / 接口密钥）。

```powershell
.\run.ps1                          # 终端 1 — 引擎
cd desktop\windows; .\run.ps1      # 终端 2 — 客户端（须独立 PowerShell 窗口）
```

安装包：`desktop/windows/build-app.ps1` 生成 zip，尚未纳入 `releases/`。详见 [desktop/windows/README.md](desktop/windows/README.md)。

---

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 作品提交 / 评审说明（macOS） |
| [docs/development.md](docs/development.md) | 本地开发、双终端启动、排错 |
| [docs/architecture.md](docs/architecture.md) | 数据流、引擎三层、App 变体 |
| [docs/windows.md](docs/windows.md) | Windows 打包与排错 |
| [docs/README.md](docs/README.md) | 文档索引 |
| [server/README.md](server/README.md) | Python 引擎与 API |
| [desktop/README.md](desktop/README.md) | macOS / Windows 客户端 |
