# macOS App

Swift 原生 UI：菜单栏控制、设置窗口、ScreenCaptureKit 采音、WebSocket 连 Python 引擎、悬浮字幕。

## 目录

```
desktop/macos/
  Package.swift
  build-app.sh          打包 VoiceBridgeAI.app
  run.sh                开发：编译并运行 Swift
  scripts/run-server.sh 打包进 .app，启动内置 Python
  Sources/VoiceBridgeAI/
    App/                VoiceBridgeAIMain、AppDelegate、MenuBarController
    Settings/           设置窗口、引擎 / 本地模型面板
    Cloud/              接口密钥面板与表单
    Capture/            屏幕录制权限、系统音频采集
    Session/            WebSocket 会话与字幕状态
    Overlay/            主窗口、悬浮字幕、控制条
    Sidecar/            Python 侧车进程、路径解析
```

### Settings/

| 文件 | 职责 |
|------|------|
| `SettingsWindowController.swift` | 设置窗口与 Tab |
| `EnginePanelView.swift` | 引擎三层选择 |
| `EngineSelectGroups.swift` | 分组下拉数据 |
| `EnginePopUpButton.swift` | 不可误点分组标题的下拉 |
| `LocalModelsPanelView.swift` | 本地模型下载/删除/切换 |
| `SettingsStore.swift` | 与引擎 API 通信 |
| `EngineConfig.swift` | 引擎配置模型 |

## 开发

```bash
# 终端 1 — 仓库根目录
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

仅调试 Swift UI（无内置引擎）：`SKIP_VENV=1 ./build-app.sh`

详见 [docs/development.md](../../docs/development.md)。

## 打包

```bash
cd desktop/macos && ./build-app.sh
open dist/VoiceBridgeAI.app
```

产物约 0.9GB（含 Python venv）。用户配置在 `~/Library/Application Support/VoiceBridgeAI/`。
