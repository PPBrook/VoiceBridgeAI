# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## macOS

### 安装包试用

| 版本 | 下载 | 体积 | 说明 |
|------|------|------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | ~428 MB | 内置 Whisper + Argos，离线可用 |
| **Cloud** | [VoiceBridgeAI-Cloud.zip](releases/VoiceBridgeAI-Cloud.zip) | ~25 MB | 仅云端 ASR/翻译，需网络 |

安装包通过 **Git LFS** 托管。浏览器打开链接直接下载；若 clone 仓库，需先执行 `git lfs pull`。

**快速开始**

1. 解压 zip → **右键打开** 对应 `.app`（未签名，首次不能双击）
2. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
3. 打开 App → **开始悬浮字幕**（播放含英文的系统音频，如浏览器视频）

配置与日志：`~/Library/Application Support/VoiceBridgeAI-Local/` 或 `VoiceBridgeAI-Cloud/`。

**详细说明**（LFS 下载、内置功能、故障排查、作品介绍）：[docs/submission.md](docs/submission.md)

### 源码开发

```bash
cp .env.example .env    # 首次；或直接使用仓库中的 .env
./run.sh                # 终端 1：Python 引擎
cd desktop/macos && ./run.sh   # 终端 2：Swift UI
```

详见 [docs/development.md](docs/development.md)。源码结构与模块说明：[desktop/README.md](desktop/README.md)。

### 打包独立 App

```bash
./run.sh                          # 确保仓库根 .venv 已创建
cd desktop/macos
./build-app-local.sh              # → dist/VoiceBridgeAI-Local.app
# 或 ./build-app-cloud.sh        # → dist/VoiceBridgeAI-Cloud.app
```

产物在 `desktop/macos/dist/`（gitignore）。发布 zip 放在 `releases/`（Git LFS）。

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
