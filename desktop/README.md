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
    App/                入口、菜单栏
    Settings/           设置窗口、引擎 / 本地模型
    Cloud/              接口密钥面板
    Capture/            屏幕录制权限、系统音频
    Session/            WebSocket 会话与字幕状态
    Overlay/            主窗口、悬浮字幕
    Sidecar/            Python 侧车进程、路径解析
```

### App/

| 文件 | 职责 |
|------|------|
| `VoiceBridgeAIMain.swift` | `@main` 入口 |
| `AppDelegate.swift` | 生命周期、overlay / 控制窗口 |
| `MenuBarController.swift` | 菜单栏图标与快捷操作 |

### Settings/

| 文件 | 职责 |
|------|------|
| `SettingsWindowController.swift` | 设置窗口 Tab |
| `EnginePanelView.swift` | 引擎三层 + 观看场景 |
| `ReviseModeGuides.swift` | 观看场景说明（服务端 catalog 的 fallback） |
| `EngineSelectGroups.swift` | 分组下拉数据 |
| `EnginePopUpButton.swift` | 不可误选分组标题的下拉 |
| `LocalModelsPanelView.swift` | 本地模型下载/删除/切换 |
| `SettingsStore.swift` | 引擎 API 封装 |
| `EngineConfig.swift` | 引擎配置与 HTTP 客户端 |

### Cloud/

| 文件 | 职责 |
|------|------|
| `CloudPanelView.swift` | 接口密钥表单与测试 |
| `ProviderSectionView.swift` | 单厂商卡片 |
| `CloudProviderGuides.swift` | 各厂商控制台链接 |
| `CloudProviderRegistry.swift` | 卡片元数据 |
| `CloudProviderPreferences.swift` | `cloud-ui.json` 同步 |
| `FormBuilder.swift` | 表单控件工厂 |

### Session / Overlay / Capture / Sidecar

| 目录 | 关键文件 | 职责 |
|------|----------|------|
| `Session/` | `SessionController`、`WebSocketSession`、`SubtitleStore` | 采音会话、WS、字幕状态 |
| `Overlay/` | `ControlWindowController`、`OverlayPanelController` | 主窗口（含观看场景）、悬浮字幕 |
| `Capture/` | `SystemAudioCapture`、`ScreenCaptureAccess` | 系统音频与权限 |
| `Sidecar/` | `ServerManager`、`SidecarLaunch`、`AppSupport`、`RepoRoot` | 引擎进程与路径 |

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
