# VoiceBridgeAI

英文音频 → 实时中文悬浮翻译。**macOS 原生 App** 为主交付；浏览器版在 [`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only) 分支。

## 仓库结构

```
VoiceBridgeAI/
├── README.md
├── docs/                     # 架构、分支、WebSocket API
├── desktop/macos/            # macOS App + build-app.sh
├── server/                   # Python 引擎
├── run.sh
├── requirements.txt
└── .env.example
```

## 快速开始

```bash
cd desktop/macos
./build-app.sh
open dist/VoiceBridgeAI.app
```

1. 屏幕录制权限  
2. App **设置 → 本地模型** 或 **接口密钥**  
3. **开始悬浮字幕**

开发者：`./run.sh` + `cd desktop/macos && ./run.sh` — 见 [desktop/README.md](desktop/README.md)。

## 文档

| 文档 | 说明 |
|------|------|
| [desktop/README.md](desktop/README.md) | macOS 安装与打包 |
| [server/README.md](server/README.md) | Python 引擎 |
| [docs/architecture.md](docs/architecture.md) | 架构 |
| [docs/branches.md](docs/branches.md) | 分支 |
| [docs/websocket-api.md](docs/websocket-api.md) | HTTP / WebSocket 协议 |
| [docs/web-legacy.md](docs/web-legacy.md) | 浏览器版（已移出本分支） |

## 分支

| 分支 | 用途 |
|------|------|
| `feat/macapp` | 独立 `.app` + 本地模型（当前） |
| `main` | 集成主干 |
| `legacy/web-only` | Web + Chromium 扩展 + YouTube CC |
