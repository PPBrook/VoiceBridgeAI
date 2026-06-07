# macOS App

Swift 原生 UI：菜单栏、设置窗口、ScreenCaptureKit 采音、WebSocket 连 Python 引擎、悬浮字幕。

## 目录

```
desktop/macos/
  Package.swift
  run.sh                     开发：编译并运行
  build-app.sh               构建脚本（参数 cloud | local）
  build-app-cloud.sh         → cloud 变体
  build-app-local.sh         → local 变体
  scripts/
    run-server.sh            App 内置侧车启动
    bundle-seed/             各变体默认 .env 种子
    prepare-bundled-models.py
  Sources/VoiceBridgeAI/
    App/                     入口、菜单栏、BundleVariant
    Settings/                引擎 / 本地模型 / 字幕记录
    Cloud/                   接口密钥（extension 拆分）
    Capture/                 屏幕录制、系统音频
    Session/                 WebSocket、字幕、记录
    Overlay/                 主窗口、悬浮字幕
    Sidecar/                 Python 侧车、路径
```

## 开发

```bash
# 终端 1 — 仓库根目录
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

详见 [docs/development.md](../docs/development.md)。

## 打包

```bash
# 仓库根目录先创建 .venv
./run.sh

cd desktop/macos
./build-app-local.sh    # dist/VoiceBridgeAI-Local.app（内置 Whisper + Argos）
./build-app-cloud.sh    # dist/VoiceBridgeAI-Cloud.app（仅云端 API）
./scripts/package-release-zip.sh cloud   # → releases/VoiceBridgeAI-Cloud.app（直接复制，不压缩）
./scripts/package-release-zip.sh local   # → releases/VoiceBridgeAI-Local.zip
```

构建脚本 `build-app.sh` 会编译 Swift release、复制 Python 侧车与 venv、合并演示用 `.env` 种子；local 变体额外运行 `prepare-bundled-models.py` 下载并打包模型。Cloud 发布为 `releases/VoiceBridgeAI-Cloud.app/`（不压缩）；Local 打 zip 见 `package-release-zip.sh`（Git LFS）。

## 模块

### App/

| 文件 | 职责 |
|------|------|
| `VoiceBridgeAIMain.swift` | `@main` 入口 |
| `AppDelegate.swift` | 生命周期、overlay / 控制窗口 |
| `MenuBarController.swift` | 菜单栏、开始/停止、打开字幕记录 |
| `BundleVariant.swift` | cloud / local / standard 变体（Info.plist） |

### Settings/

| 文件 | 职责 |
|------|------|
| `SettingsWindowController.swift` | 设置 Tab（云端版隐藏本地模型） |
| `EnginePanelView.swift` | 引擎三层 + 观看场景 |
| `ReviseModeGuides.swift` | 观看场景说明 |
| `EngineSelectGroups.swift` | 分组下拉数据 |
| `EnginePopUpButton.swift` | 下拉控件 |
| `LocalModelsPanelView.swift` | 本地模型 UI |
| `LocalModelDownloadCoordinator.swift` | 下载进度轮询 |
| `LocalModelsWhisperSupport.swift` | Whisper 规格文案 |
| `TranscriptSettingsPanelView.swift` | 字幕记录设置 |
| `TranscriptPreferences.swift` | 记录路径、模板、形式、记录开关 |
| `SettingsStore.swift` | 引擎 API |
| `EngineConfig.swift` | HTTP 客户端 |

### Cloud/

| 文件 | 职责 |
|------|------|
| `CloudPanelView.swift` | 接口密钥主面板 |
| `CloudPanelView+Providers.swift` | 厂商卡片 |
| `CloudPanelView+Testing.swift` | 连通性测试 |
| `CloudPanelView+Credentials.swift` | 密钥保存 |
| `ProviderSectionView.swift` | 单厂商卡片 |
| `CloudProviderGuides.swift` | 控制台链接 |
| `CloudProviderRegistry.swift` | 卡片元数据 |
| `CloudProviderPreferences.swift` | `cloud-ui.json` |
| `FormBuilder.swift` | 表单工厂 |

### Session

| 文件 | 职责 |
|------|------|
| `SessionController.swift` | 采音会话、热更新 |
| `WebSocketSession.swift` | WS 连接 |
| `SubtitleStore.swift` | 字幕状态（2 行） |
| `PcmSilenceMonitor.swift` | 静音清屏 |
| `TranslationRecorder.swift` | 定稿句写文件 |
| `TranscriptDocument.swift` | 解析 / 渲染 / 转换 |

### Overlay

| 文件 | 职责 |
|------|------|
| `ControlWindowController.swift` | 主窗口 |
| `OverlayPanelController.swift` | 悬浮字幕 UI |
| `OverlayPreferences.swift` | 背景/文字透明度、英文显示 |

### Capture / Sidecar

| 目录 | 关键文件 | 职责 |
|------|----------|------|
| `Capture/` | `SystemAudioCapture`、`ScreenCaptureAccess` | 系统音频与权限 |
| `Sidecar/` | `ServerManager`、`SidecarLaunch`、`AppSupport`、`RepoRoot` | 引擎进程与数据目录 |

## App 变体

| 变体 | 产物 | 说明 |
|------|------|------|
| 开发 | `./run.sh` | 连仓库根目录引擎，全功能 |
| cloud | `VoiceBridgeAI-Cloud.app` | 无本地模型 Tab，依赖云端 API |
| local | `VoiceBridgeAI-Local.app` | 可内置 Whisper + Argos |

构建脚本在 `build-app*.sh`；产物在 `dist/`（gitignore）。
