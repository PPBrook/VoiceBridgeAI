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
    Settings/           设置窗口（引擎 / 本地模型 / 字幕记录 / 接口密钥）
    Cloud/              接口密钥面板（含 extension 拆分）
    Capture/            屏幕录制权限、系统音频
    Session/            WebSocket 会话、字幕状态、记录导出
    Overlay/            主窗口、悬浮字幕
    Sidecar/            Python 侧车进程、路径解析
```

### App/

| 文件 | 职责 |
|------|------|
| `VoiceBridgeAIMain.swift` | `@main` 入口 |
| `AppDelegate.swift` | 生命周期、overlay / 控制窗口 |
| `MenuBarController.swift` | 菜单栏图标、开始/停止、打开字幕记录 |

### Settings/

| 文件 | 职责 |
|------|------|
| `SettingsWindowController.swift` | 设置窗口 Tab |
| `EnginePanelView.swift` | 引擎三层 + 观看场景 |
| `ReviseModeGuides.swift` | 观看场景说明（服务端 catalog 的 fallback） |
| `EngineSelectGroups.swift` | 分组下拉数据 |
| `EnginePopUpButton.swift` | 不可误选分组标题的下拉 |
| `LocalModelsPanelView.swift` | 本地模型 UI 主文件 |
| `LocalModelDownloadCoordinator.swift` | 下载进度轮询 |
| `LocalModelsWhisperSupport.swift` | Whisper 规格与状态文案 |
| `TranscriptSettingsPanelView.swift` | 字幕记录目录、文件名、形式、转换 |
| `TranscriptPreferences.swift` | 记录路径 / 模板 / 内容形式偏好 |
| `SettingsStore.swift` | 引擎 API 封装 |
| `EngineConfig.swift` | 引擎配置与 HTTP 客户端 |

### Cloud/

| 文件 | 职责 |
|------|------|
| `CloudPanelView.swift` | 接口密钥面板主文件 |
| `CloudPanelView+Providers.swift` | 厂商卡片注册与布局 |
| `CloudPanelView+Testing.swift` | 连通性测试与 badge |
| `CloudPanelView+Credentials.swift` | 密钥绑定与保存 |
| `ProviderSectionView.swift` | 单厂商卡片 |
| `CloudProviderGuides.swift` | 各厂商控制台链接 |
| `CloudProviderRegistry.swift` | 卡片元数据 |
| `CloudProviderPreferences.swift` | `cloud-ui.json` 同步 |
| `FormBuilder.swift` | 表单控件工厂 |

### Session

| 文件 | 职责 |
|------|------|
| `SessionController.swift` | 采音会话生命周期、热更新 |
| `WebSocketSession.swift` | WS 连接与消息 |
| `SubtitleStore.swift` | 悬浮字幕状态（显示 2 行） |
| `PcmSilenceMonitor.swift` | 暂停时静音检测，自动清空旧字幕 |
| `TranslationRecorder.swift` | 定稿句写入文件 |
| `TranscriptDocument.swift` | 记录解析 / 渲染 / 格式转换 |

### Overlay

| 文件 | 职责 |
|------|------|
| `ControlWindowController.swift` | 主窗口（观看场景、开始/停止） |
| `OverlayPanelController.swift` | 悬浮字幕 UI |
| `OverlayPreferences.swift` | 背景/文字透明度、英文显示、记录开关 |

### Capture / Sidecar

| 目录 | 关键文件 | 职责 |
|------|----------|------|
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
