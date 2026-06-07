# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## 评审 / 老师试用

1. 下载 **[releases/VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip)**（Git LFS，约 442 MB）
2. 解压 → **右键打开** `VoiceBridgeAI-Local.app`
3. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
4. 打开 App → **开始悬浮字幕**

**详细说明**（LFS 下载方式、内置功能、故障排查、作品介绍）：[docs/submission.md](docs/submission.md)

**云端版**（约 24 MB，无本地模型，依赖云端 API）：[releases/VoiceBridgeAI-Cloud.zip](releases/VoiceBridgeAI-Cloud.zip)

---

## 开发与源码

| 文档 | 内容 |
|------|------|
| [docs/development.md](docs/development.md) | 本地开发、双终端启动、排错 |
| [docs/architecture.md](docs/architecture.md) | 数据流、引擎三层、App 变体 |
| [docs/README.md](docs/README.md) | 文档索引 |
| [server/README.md](server/README.md) | Python 引擎与 API |
| [desktop/README.md](desktop/README.md) | macOS 源码结构 |

```bash
cp .env.example .env    # 或直接使用仓库中的 .env
./run.sh
cd desktop/macos && ./run.sh
```
