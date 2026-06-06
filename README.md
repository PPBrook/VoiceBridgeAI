# VoiceBridgeAI macOS 桌面客户端

Swift + AppKit + ScreenCaptureKit 原生客户端。**独立 `.app` 版内置 Python 引擎**，用户无需克隆仓库或手动 `run.sh`。

浏览器版见分支 **`legacy/web-only`**。

## 功能

| 能力 | 说明 |
|------|------|
| 系统音频采集 | ScreenCaptureKit → WebSocket |
| 悬浮字幕 | 双行、partial、纠正、透明度 |
| App 内设置 | 引擎 + 云端密钥 + 本地模型下载 |
| **内置引擎** | Python 侧车打包在 `.app` 内，自动启动 |
| 配置持久化 | `~/Library/Application Support/VoiceBridgeAI/.env` |

## 要求

- macOS **13+**
- 打包机需 **Python 3.10+**（仅开发者 `build-app.sh` 时用）
- 最终用户 **只需安装 `.app`**

## 用户：只装 App

1. 拿到 `VoiceBridgeAI.app`（拖入「应用程序」）
2. 双击打开（未签名需在「隐私与安全性」允许一次）
3. **系统设置 → 隐私 → 屏幕录制** → 允许 VoiceBridgeAI
4. **设置 → 本地模型** 下载 Whisper/Argos，或 **接口密钥** 配云端
5. **开始字幕**

配置与日志：

```
~/Library/Application Support/VoiceBridgeAI/
├── .env          # 引擎 / 密钥（App 内保存）
├── server.log    # 侧车日志
└── models/       # 可选下载的 Whisper / Argos
```

## 开发者：打包独立 App

```bash
cd desktop/macos
chmod +x build-app.sh
./build-app.sh          # 含 pip 安装，约 3–8 分钟
open dist/VoiceBridgeAI.app
```

快速调试 Swift UI（不含 Python，**.app 不能独立运行**）：

```bash
SKIP_VENV=1 ./build-app.sh
```

开发模式（仓库 + `run.sh`，不打包侧车）：

```bash
./run.sh
```

## 架构

```
VoiceBridgeAI.app
├── Contents/MacOS/VoiceBridgeAI     ← Swift UI
└── Contents/Resources/
    ├── run-server.sh
    ├── python-venv/                 ← 内置依赖
    └── server/                      ← FastAPI 引擎
```

App 启动 → 检测 `127.0.0.1:8765` → 不可达则执行 `run-server.sh` → WebSocket 会话。

## 本地模型

默认 **按需下载**（不增大 App 本体内核体积；Whisper/Argos 仍须首次下载）。

## 已知限制

- 未代码签名 / 公证（比赛 demo 可接受）
- App 体积约 **500MB–1GB**（含 Python + ML 依赖，不含 Whisper 权重）
- 无 YouTube CC 模式
- 仅本机 `127.0.0.1`

## 故障排查

| 现象 | 处理 |
|------|------|
| 启动失败 | 查看 `~/Library/Application Support/VoiceBridgeAI/server.log` |
| 无 Whisper/Argos | 设置 → 本地模型 → 下载 |
| 无声音 | 屏幕录制权限 |
| 改设置无效 | 停止字幕后重新开始 |

根目录 [README.md](../README.md)
