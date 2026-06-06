# VoiceBridgeAI 桌面客户端（macOS 原生）

Swift + AppKit + ScreenCaptureKit。无需 Node / Electron。

- 自动拉起现有 Python 服务（`../../run.sh`）
- **App 内设置**：引擎选择 + 云端密钥（对应 Web `/` 与 `/config`）
- **系统音频** → WebSocket → 与扩展 **同一套** `server/`
- 置顶悬浮字幕窗 + 控制面板

## 设置（App 内）

主窗口点 **设置…**：

| 标签 | 内容 |
|---|---|
| **引擎** | 语音识别 / 句中翻译 / 句末润色 / 纠正模式 → 保存到服务端 |
| **接口密钥** | 腾讯、七牛、阿里、百度、DeepL、DeepSeek、OpenAI → 保存到 `.env`、单项测试、一键测试 |

与 Web 控制台、`/config` 共用同一套 API，无需再开浏览器（可选）。

- **macOS 13+**
- Swift 6（Xcode 或 Command Line Tools）
- 仓库根目录 Python 环境可用（`./run.sh` 能跑）

## 运行

```bash
cd desktop/macos
./run.sh
```

或：

```bash
cd desktop/macos
swift build -c release
VOICEBRIDGE_ROOT=/path/to/VoiceBridgeAI .build/release/VoiceBridgeAI
```

首次使用：**系统设置 → 隐私与安全性 → 屏幕录制**，允许 `VoiceBridgeAI`（ScreenCaptureKit 采系统声需要）。

## 架构

```
desktop/macos/Sources/VoiceBridgeAI/
├── VoiceBridgeAIMain.swift      入口
├── AppDelegate.swift            应用生命周期
├── ControlWindowController.swift  控制面板
├── OverlayPanelController.swift   悬浮字幕
├── SettingsWindowController.swift  设置窗（引擎 + 密钥）
├── EnginePanelView.swift / CloudPanelView.swift
├── SettingsStore.swift / APIClient.swift
├── SystemAudioCapture.swift     ScreenCaptureKit 音频
├── WebSocketSession.swift       与 server/ws 协议一致
├── ServerManager.swift          拉起 run.sh、读 /api/health
└── SubtitleStore.swift          字幕状态

server/ + static/                 未改，Web / 扩展 / 桌面共用
extension/                        未动
```

## 与扩展

| | Chromium 扩展 | macOS 原生 |
|---|---|---|
| 音频 | 当前标签页 | 系统音频 |
| 字幕 | 网页内 | 屏幕置顶窗 |
| YouTube CC | ✅ | ❌ 未做 |
| Node | 不需要 | 不需要 |

## 后续

- [ ] `.app` 打包与代码签名
- [ ] 云端-only 瘦身 Python 侧车
- [ ] Windows 版（WASAPI loopback）

## 说明

当前为 **可运行的 MVP**。若找不到 `run.sh`，设置环境变量：

```bash
export VOICEBRIDGE_ROOT=/Users/you/VoiceBridgeAI
```
