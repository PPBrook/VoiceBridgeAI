# Windows App（feat/winapp）

原生 Windows 壳 + 内置 Python 侧车，协议与 [macOS 版](../macos/README.md) 一致。

## 目录结构

```
desktop/windows/
  VoiceBridgeAI/              # WinUI 3 解决方案
    App/                      # 入口、BundleVariant
    Capture/                  # WASAPI 环回采集（NAudio）
    Session/                  # WebSocket、SubtitleStore、字幕记录
    Overlay/                  # 置顶透明悬浮字幕
    Settings/                 # 设置窗（引擎 / 本地模型 / 字幕记录 / 接口密钥）
    Sidecar/                  # ServerManager、AppSupport
    Tray/                     # 通知区托盘
  scripts/
    run-server.ps1            # 打包版侧车启动
    bundle-seed/              # cloud.env / local.env
    prepare-bundled-models.py # local 打包时下载模型
  check-build-env.ps1         # 首次编译环境检查
  run.ps1                     # 开发：编译并运行客户端
  build-app.ps1               # 打包 cloud | local
  dist/                       # 打包产物（gitignore）
```

## macOS → Windows 对照

| macOS | Windows |
|-------|---------|
| `SystemAudioCapture` (ScreenCaptureKit) | WASAPI loopback（NAudio） |
| `OverlayPanelController` (NSPanel) | 无边框置顶 WinUI `OverlayWindow` |
| `MenuBarController` | 托盘图标 + 上下文菜单 |
| `SettingsWindowController` | `SettingsWindow`（TabView） |
| `TranslationRecorder` | `Session/TranslationRecorder.cs` |
| `SidecarLaunch` + `run-server.sh` | `ServerManager` + `run-server.ps1` |
| `AppSupport` | `%APPDATA%\VoiceBridgeAI{-Cloud,-Local}\` |
| `BundleVariant` | `bundle-variant.txt` 或环境变量 |

## 侧车契约（与 macOS 相同，不改协议）

| 用途 | 地址 |
|------|------|
| 健康检查 | `GET http://127.0.0.1:8765/api/health` |
| WebSocket | `ws://127.0.0.1:8765/ws` |
| 引擎设置 | `POST /api/engine/settings` |
| 云端密钥 | `POST /api/cloud/settings` |
| 本地模型 | `POST /api/models/local/*` |

音频：首包 JSON `config` → 二进制 PCM（48 kHz mono Int16 LE）→ JSON `type: asr`。

环境变量：`VOICEBRIDGE_PORT`、`VOICEBRIDGE_DATA_DIR`、`VOICEBRIDGE_BUNDLE_VARIANT`。

## 功能进度

| 阶段 | 内容 | 状态 |
|------|------|------|
| 0 | `run.ps1`、Windows 数据目录、文档 | ✅ |
| 1 | 托盘 + 侧车 + 健康检查 | ✅ |
| 2 | WebSocket 会话 + 悬浮字幕 | ✅ |
| 3 | WASAPI 系统音频环回 | ✅ |
| 4 | 设置窗四 Tab + 悬浮「记」+ 托盘打开记录目录 | ✅ |
| 5 | `build-app.ps1` cloud / local 打包 | ✅ 脚本就绪 |

### 设置窗 Tab

| Tab | 说明 |
|-----|------|
| **引擎** | ASR / 句中翻译 / 句末润色 / 观看场景 |
| **本地模型** | Whisper / Argos 下载、切换、删除（Cloud 变体无此 Tab） |
| **字幕记录** | 目录、文件名模板、格式与内容形式、转换已有文件 |
| **接口密钥** | 腾讯云 / OpenAI / DeepL 等，单项测试与一键测试 |

### 悬浮字幕顶栏

| 控件 | 说明 |
|------|------|
| **背景** / **文字** | 面板与字幕透明度 |
| **记** | 字幕记录开关（同步设置 → 字幕记录） |
| **EN** | 显示/隐藏英文原文 |
| 标题区拖动 | 移动浮窗（位置持久化） |
| **×** | 停止字幕会话 |

### 与 macOS 的差异（已知）

| 项目 | macOS | Windows（当前） |
|------|-------|-----------------|
| 主窗口关闭 | 收起到菜单栏 | 退出进程 |
| 权限 | 屏幕录制（采系统声） | 无需额外权限（WASAPI 环回） |
| 打开记录目录 | Finder | 资源管理器 |
| 安装包 | `.app` + zip | 文件夹 + zip（未代码签名） |

## 开发

### 环境

- Windows 10 19041+（推荐 Windows 11）
- [.NET 8 SDK](https://dotnet.microsoft.com/download)（仓库 `global.json` 建议 8.0.421）
- [Windows App SDK 1.6 Runtime](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads)（运行已编译客户端）
- 首次编译：`.\check-build-env.ps1`（可选 VS Build Tools + Windows SDK）

### 双终端启动（必须）

```powershell
# 终端 1 — 引擎（保持运行）
cd C:\Users\pengp\VoiceBridgeAI
.\run.ps1

# 终端 2 — 客户端（新开窗口，勿与终端 1 粘在同一段）
cd C:\Users\pengp\VoiceBridgeAI\desktop\windows
.\run.ps1
```

若终端 1 提示端口 8765 已占用且 health 正常，说明引擎已在跑，**直接开终端 2**。

仅验引擎（任意平台）：

```powershell
cd <repo-root>
.\run.ps1
curl http://127.0.0.1:8765/api/health
```

改 Python（`server/`）→ 终端 1 `Ctrl+C` 后重跑 `.\run.ps1`。  
改客户端 → 终端 2 `Ctrl+C` 后重跑 `desktop\windows\run.ps1`（自动 `dotnet build`）。

### 数据与字幕目录

| 场景 | 路径 |
|------|------|
| 开发（引擎） | 仓库根目录 `.env`、`models/` |
| 标准 App | `%APPDATA%\VoiceBridgeAI\` |
| Cloud 变体 | `%APPDATA%\VoiceBridgeAI-Cloud\` |
| Local 变体 | `%APPDATA%\VoiceBridgeAI-Local\` |
| 字幕记录（默认） | 上述 App 目录下 `transcripts\` |

客户端偏好：`overlay-prefs.json`、`transcript-prefs.json` 同在 App 数据目录。

## 打包

产物在 `desktop/windows/dist/`（gitignore）。

### 便携包（zip，无需额外工具）

```powershell
cd desktop\windows

# 云端版（约 100–200 MB，需填 API 密钥）
$env:BUNDLE_COPY_VENV = "1"    # 复用仓库 .venv，加快打包
.\build-app.ps1 cloud

# 本地版（含 Whisper + Argos，数百 MB，需网络或 VOICEBRIDGE_MODELS_SOURCE）
.\build-app.ps1 local
```

输出：`dist\VoiceBridgeAI-Cloud\` + `VoiceBridgeAI-Cloud.zip`（local 同理）。

用户解压后运行 `VoiceBridgeAI.exe` 即可；配置写入 `%APPDATA%\VoiceBridgeAI-Cloud\` 或 `VoiceBridgeAI-Local\`。

### 安装程序（Setup.exe，可选）

需先安装 [Inno Setup 6](https://jrsoftware.org/isinfo.php)：

```powershell
winget install -e --id JRSoftware.InnoSetup
```

然后：

```powershell
cd desktop\windows
$env:BUNDLE_COPY_VENV = "1"
.\build-app.ps1 cloud -Setup
```

额外生成 `dist\VoiceBridgeAI-Cloud-Setup.exe`：安装到 `%LOCALAPPDATA%\Programs\`、开始菜单快捷方式、卸载项。

### 环境变量

| 变量 | 说明 |
|------|------|
| `BUNDLE_COPY_VENV=1` | 复用仓库 `.venv`（推荐） |
| `SKIP_VENV=1` | 跳过 venv（包无法独立运行） |
| `SKIP_MODELS=1` | local 跳过模型下载 |
| `VOICEBRIDGE_MODELS_SOURCE` | 复制已有 `models/` |
| `BUNDLE_DEMO_SECRETS=1` | cloud 也合并演示密钥 |

打包细节、Smart App Control、Runtime 见 [docs/windows.md](../../docs/windows.md)。

## 延伸阅读

- 开发流程与排错：[docs/development.md](../../docs/development.md)
- Windows 专题（打包、签名、Runtime）：[docs/windows.md](../../docs/windows.md)
- 架构与变体：[docs/architecture.md](../../docs/architecture.md)
- Python 引擎 API：[server/README.md](../../server/README.md)
