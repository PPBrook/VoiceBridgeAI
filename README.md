# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## macOS

### 安装包试用

| 版本 | 获取 | 说明 |
|------|------|------|
| **Local**（推荐） | [releases/VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | 内置 Whisper + Argos，离线可用（Git LFS，约 428 MB） |
| **Cloud** | [releases/VoiceBridgeAI-Cloud.app](releases/VoiceBridgeAI-Cloud.app) | 仅云端 ASR/翻译（约 77 MB，clone 后直接使用） |

下载与试用步骤见 [docs/submission.md](docs/submission.md)。

**快速开始**

1. **右键打开** `.app`（未签名，首次不能双击）
2. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
3. 打开 App → **开始悬浮字幕**

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

产物在 `desktop/macos/dist/`（gitignore），本地安装：拖入「应用程序」即可。

---

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 作品提交 / 评审说明 |
| [docs/development.md](docs/development.md) | 本地开发、双终端启动、排错 |
| [docs/architecture.md](docs/architecture.md) | 数据流、引擎三层、App 变体 |
| [docs/README.md](docs/README.md) | 文档索引 |
| [server/README.md](server/README.md) | Python 引擎与 API |
| [desktop/README.md](desktop/README.md) | macOS 源码结构 |
