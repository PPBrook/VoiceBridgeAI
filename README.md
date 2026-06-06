# VoiceBridgeAI

英文音频 / 字幕 → 实时中文悬浮翻译。当前主开发线为 **macOS 原生 App**；浏览器扩展与 Web 控制台归档在 [`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only) 分支。

## 仓库结构

```
VoiceBridgeAI/
├── README.md                 # 本文件：项目总览
├── docs/                     # 架构、分支、协议说明
├── desktop/macos/            # macOS App（Swift UI + 打包脚本）
├── server/                   # Python 引擎（ASR / 翻译 / WebSocket）
├── extension/                # [归档] Chromium 扩展（本分支仅保留，见 docs/web-legacy.md）
├── static/                   # [归档] Web 控制台
├── run.sh                    # 开发：启动 Python 引擎
├── requirements.txt
└── .env.example
```

## 快速开始

### macOS 用户（推荐）

```bash
cd desktop/macos
./build-app.sh
open dist/VoiceBridgeAI.app
```

1. 授予 **屏幕录制** 权限  
2. App 内 **设置 → 本地模型** 或 **接口密钥**  
3. **开始悬浮字幕**

详见 [desktop/README.md](desktop/README.md)。

### 开发者（改引擎 / 调试侧车）

```bash
cp .env.example .env
./run.sh
cd desktop/macos && ./run.sh
```

## 架构概览

```
系统音频 ──► macOS App (Swift) ──WebSocket──► Python server/ ──► 字幕回 App overlay
```

- **App**：采音、UI、设置、可选内置 Python 侧车  
- **server/**：Whisper / 腾讯云 / OpenAI + 多厂商翻译 + 纠正  

详见 [docs/architecture.md](docs/architecture.md)。

## 分支

| 分支 | 用途 |
|------|------|
| `main` | 集成分支（含桌面 MVP） |
| `feat/macapp` | 独立 `.app` + 本地模型按需下载 |
| `feat/desktop-client` | 桌面 MVP（仓库 + `run.sh`） |
| `legacy/web-only` | 浏览器版保底（Web + 扩展 + YouTube CC） |

详见 [docs/branches.md](docs/branches.md)。

## 文档索引

| 文档 | 说明 |
|------|------|
| [desktop/README.md](desktop/README.md) | macOS 安装、打包、故障排查 |
| [server/README.md](server/README.md) | Python 引擎与 API |
| [docs/architecture.md](docs/architecture.md) | 系统架构 |
| [docs/branches.md](docs/branches.md) | 分支策略 |
| [docs/web-legacy.md](docs/web-legacy.md) | 浏览器版（归档） |
| [extension/API.md](extension/API.md) | WebSocket 协议（桌面共用） |

## 环境变量

复制 `.env.example`。App 独立安装时配置写入  
`~/Library/Application Support/VoiceBridgeAI/.env`（开发模式为仓库根 `.env`）。

常用项：`VOICEBRIDGE_PORT`、`VOICEBRIDGE_OPTIONAL_LOCAL_MODELS`、`ASR_PROVIDER`、`PARTIAL_PROVIDER`、`FINAL_PROVIDER`。
