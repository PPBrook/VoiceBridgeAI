# macOS 桌面客户端

Swift + AppKit + ScreenCaptureKit。**独立 `.app` 内置 Python 引擎**，最终用户无需克隆仓库。

项目总览见 [../README.md](../README.md)。

## 功能

| 能力 | 说明 |
|------|------|
| 系统音频 | ScreenCaptureKit → mono PCM → WebSocket |
| 悬浮字幕 | 双行、partial `…`、纠正闪色、背景透明度 |
| 设置 | 引擎 / 云端密钥 / 本地模型下载 |
| 侧车 | `.app` 内自动启动；开发模式用仓库 `run.sh` |
| 配置 | `~/Library/Application Support/VoiceBridgeAI/` |

## 用户：只装 App

1. 安装 `VoiceBridgeAI.app`（`build-app.sh` 产物或分发包）
2. 系统设置 → **屏幕录制** → 允许 VoiceBridgeAI
3. **设置 → 本地模型** 下载 Whisper/Argos，或 **接口密钥** 配云端
4. **设置 → 引擎** 保存 → **开始悬浮字幕**

未签名 App：系统设置 → 隐私与安全性 → **仍要打开**。

### 配置与日志

```
~/Library/Application Support/VoiceBridgeAI/
├── .env
├── server.log
└── models/          # Whisper / Argos 按需下载
```

## 开发者

### 打包独立 App

```bash
cd desktop/macos
chmod +x build-app.sh run.sh
./build-app.sh              # 完整包，约 3–8 分钟
open dist/VoiceBridgeAI.app
```

仅调试 Swift UI（无 Python，App 不能独立运行）：

```bash
SKIP_VENV=1 ./build-app.sh
```

### 开发模式（仓库 + run.sh）

```bash
# 终端 1：仓库根
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

### 目录结构

```
desktop/macos/
├── Package.swift
├── Info.plist
├── run.sh                 # swift build + 启动可执行文件
├── build-app.sh           # 生成 dist/VoiceBridgeAI.app
├── scripts/
│   └── run-server.sh      # 打包进 .app，启动内置 Python
└── Sources/VoiceBridgeAI/
    ├── VoiceBridgeAIMain.swift
    ├── AppDelegate.swift
    ├── ControlWindowController.swift
    ├── SettingsWindowController.swift
    ├── EnginePanelView.swift
    ├── CloudPanelView.swift
    ├── LocalModelsPanelView.swift
    ├── SessionController.swift
    ├── WebSocketSession.swift
    ├── ServerManager.swift
    ├── SidecarLaunch.swift
    ├── AppSupport.swift
    ├── SystemAudioCapture.swift
    ├── ScreenCaptureAccess.swift
    ├── OverlayPanelController.swift
    ├── SubtitleStore.swift
    ├── MenuBarController.swift
    ├── SettingsStore.swift
    ├── EngineConfig.swift
    ├── RepoRoot.swift
    └── …（FormBuilder、EngineSelectGroups 等）
```

编译产物：`desktop/macos/.build/`、`dist/`（已 gitignore）。

## 独立 App 内部布局

```
VoiceBridgeAI.app/Contents/
├── MacOS/VoiceBridgeAI
└── Resources/
    ├── run-server.sh
    ├── python-venv/
    └── server/            # 打包时从仓库 server/ 复制
```

## 已知限制

- 无代码签名 / 公证
- App 约 500MB–1GB（含 Python 依赖，不含 Whisper 权重）
- 无 YouTube CC 模式
- 仅本机 `127.0.0.1`

## 故障排查

| 现象 | 处理 |
|------|------|
| 启动失败 | `~/Library/Application Support/VoiceBridgeAI/server.log` |
| 无 Whisper/Argos | 设置 → 本地模型 → 下载 |
| 无声音 | 屏幕录制权限；重启 App |
| 改设置无效 | 停止字幕后重新开始 |
| 端口占用 | `kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)` |
