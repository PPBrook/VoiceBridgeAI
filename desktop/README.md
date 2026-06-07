# Desktop 客户端

| 平台 | 目录 | 技术栈 | 状态 |
|------|------|--------|------|
| macOS | [macos/](macos/) | Swift + AppKit + ScreenCaptureKit | ✅ 主分支维护，含 releases |
| Windows | [windows/](windows/) | C# / WinUI 3 + WASAPI (NAudio) | ✅ 功能对齐 macOS 壳；打包脚本就绪 |

两端共用 **同一 Python 引擎**（`server/`）：`http://127.0.0.1:8765` + `ws://127.0.0.1:8765/ws`。

## 功能对照

| 功能 | macOS | Windows |
|------|-------|---------|
| 系统音频采集 | ScreenCaptureKit | WASAPI loopback |
| 悬浮字幕 | NSPanel | WinUI 置顶窗 |
| 设置 · 引擎 | ✅ | ✅ |
| 设置 · 本地模型 | ✅（cloud 无 Tab） | ✅（cloud 无 Tab） |
| 设置 · 字幕记录 | ✅ | ✅ |
| 设置 · 接口密钥 | ✅ | ✅ |
| 托盘 / 菜单栏 | 菜单栏 | 通知区托盘 |
| Cloud / Local 打包 | `build-app.sh` | `build-app.ps1` |

## 开发入口

**macOS**

```bash
# 终端 1
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

**Windows**

```powershell
# 终端 1
.\run.ps1

# 终端 2
cd desktop\windows
.\check-build-env.ps1   # 首次
.\run.ps1
```

详见 [docs/development.md](../docs/development.md)。

## 打包

### macOS

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

### Windows

```powershell
cd desktop\windows
.\build-app.ps1 cloud    # dist\VoiceBridgeAI-Cloud\ + zip
.\build-app.ps1 local    # 内置 venv + 模型
```

详见 [windows/README.md](windows/README.md) · [docs/windows.md](../docs/windows.md)。

## macOS 模块（`Sources/VoiceBridgeAI/`）

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
| `LocalModelsPanelView.swift` | 本地模型 UI |
| `TranscriptSettingsPanelView.swift` | 字幕记录设置 |
| `SettingsStore.swift` | 引擎 / 云端 / 本地模型 API |

### Cloud/

| 文件 | 职责 |
|------|------|
| `CloudPanelView.swift` | 接口密钥主面板 |
| `CloudProviderRegistry.swift` | 厂商卡片元数据 |

### Session / Overlay / Sidecar

| 目录 | 关键文件 | 职责 |
|------|----------|------|
| `Session/` | `SessionController`、`TranslationRecorder` | WebSocket 会话、字幕记录 |
| `Overlay/` | `OverlayPanelController` | 悬浮字幕 UI |
| `Capture/` | `SystemAudioCapture` | 系统音频与权限 |
| `Sidecar/` | `ServerManager`、`SidecarLaunch` | 引擎进程与数据目录 |

## App 变体

| 变体 | macOS 产物 | Windows 产物 |
|------|------------|--------------|
| 开发 | `./run.sh` | `run.ps1` + `desktop/windows/run.ps1` |
| cloud | `VoiceBridgeAI-Cloud.app` | `VoiceBridgeAI-Cloud/` + zip |
| local | `VoiceBridgeAI-Local.app` | `VoiceBridgeAI-Local/` + zip |

构建产物在 `dist/`（gitignore）；macOS releases 见 `releases/`（LFS）。

## 文档

| 文档 | 内容 |
|------|------|
| [macos/README.md](macos/README.md) | macOS 目录与变体 |
| [windows/README.md](windows/README.md) | Windows 目录、进度、双终端 |
| [docs/development.md](../docs/development.md) | 双端开发流程 |
| [docs/windows.md](../docs/windows.md) | Windows 打包与排错 |
