# Windows App（feat/winapp）

原生 Windows 壳 + 内置 Python 侧车，协议与 [macOS 版](../macos/README.md) 一致。

## 目标结构（对齐 macOS）

```
desktop/windows/
  VoiceBridgeAI/              # WinUI 3 解决方案
    App/                      # 入口、BundleVariant
    Capture/                  # WASAPI 环回采集
    Session/                  # WebSocket、SubtitleStore、SessionController
    Overlay/                  # 置顶透明悬浮字幕
    Settings/                 # EngineConfig、SettingsStore（Phase 4 扩展）
    Sidecar/                  # 启动 python-venv + server
  scripts/
    run-server.ps1            # 打包版侧车启动（待建）
    bundle-seed/              # cloud.env / local.env（待建）
  run.ps1                     # 开发：启动客户端（待建）
  build-app.ps1               # 打包 cloud | local（待建）
```

## macOS → Windows 模块对照

| macOS | Windows（计划） |
|-------|-----------------|
| `SystemAudioCapture` (ScreenCaptureKit) | WASAPI loopback (`IAudioClient` / NAudio) |
| `OverlayPanelController` (NSPanel) | 无边框置顶 WinUI / HWND layered window |
| `MenuBarController` | 通知区托盘图标 + 上下文菜单 |
| `SidecarLaunch` + `run-server.sh` | `ProcessStartInfo` + `run-server.ps1` |
| `AppSupport` | `%APPDATA%\VoiceBridgeAI{-Cloud,-Local}\` |
| `BundleVariant` | 构建常量或 `bundle-variant.txt` |

## 侧车契约（复用，不改动协议）

- 健康检查：`GET http://127.0.0.1:8765/api/health`
- WebSocket：`ws://127.0.0.1:8765/ws`
- 首包 JSON config → 二进制 PCM（48kHz mono Int16 LE）→ JSON `type: asr`
- 环境变量：`VOICEBRIDGE_PORT`、`VOICEBRIDGE_DATA_DIR`、`VOICEBRIDGE_BUNDLE_VARIANT`

详见 [docs/windows.md](../../docs/windows.md)。

## 当前进度

- [x] 分支 `feat/winapp`
- [x] Windows 数据目录（`server/config/app_paths.py`）
- [x] 根目录 `run.ps1` 启动引擎
- [x] WinUI 3 客户端（Phase 1：托盘 + 侧车 + 健康检查）
- [x] WebSocket 会话 + 悬浮字幕 Overlay（Phase 2）
- [x] WASAPI 系统音频环回采集（Phase 3）
- [ ] 设置窗
- [ ] `build-app.ps1` 打包

## 开发

**仅引擎（任意平台可先验 Python）：**

```powershell
cd <repo-root>
.\run.ps1
curl http://127.0.0.1:8765/api/health
```

**Windows 客户端（需 Windows 10+、.NET 8 SDK、Windows App SDK）：**

```powershell
cd desktop\windows
.\run.ps1
```

托盘图标 + 主窗口 → **开始悬浮字幕** → 采集系统播放声 → 屏幕底部悬浮中文翻译。设置窗与打包见 Phase 4–5（[docs/windows.md](../../docs/windows.md)）。
