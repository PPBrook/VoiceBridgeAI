# Windows 客户端（feat/winapp）

## 原则

与 macOS 相同：**原生 UI 壳 + 复用 `server/` 引擎**，不重写 ASR/翻译/WebSocket 逻辑。

```
WASAPI 环回 (PCM 48k mono)
        ↓
Windows 客户端 (C# / WinUI 3)
        ↓  ws://127.0.0.1:8765/ws
server/  （与 macOS 共用）
        ↓
悬浮字幕 Overlay + 可选字幕记录
```

## 阶段规划

| 阶段 | 内容 | 状态 |
|------|------|------|
| **0** | `run.ps1`、Windows `APPDATA` 路径、文档 | ✅ |
| **1** | 托盘 + 侧车 + `ServerManager` | ✅ |
| **2** | WebSocket 会话 + 悬浮字幕 | ✅ |
| **3** | WASAPI 系统音频采集（NAudio loopback） | ✅ |
| **4** | 设置窗四 Tab、字幕记录、悬浮「记」 | ✅ |
| **5** | `build-app.ps1` cloud / local | ✅ |

细节与目录说明：[desktop/windows/README.md](../desktop/windows/README.md)。

## 数据目录

| 场景 | 路径 |
|------|------|
| 开发（仓库 `run.ps1`） | 仓库根目录 |
| 安装版标准 | `%APPDATA%\VoiceBridgeAI\` |
| Cloud 变体 | `%APPDATA%\VoiceBridgeAI-Cloud\` |
| Local 变体 | `%APPDATA%\VoiceBridgeAI-Local\` |

`.env`、`cloud-ui.json`、`server.log`、`models/`、`transcripts/` 布局与 macOS Application Support 一致。  
客户端额外写入：`overlay-prefs.json`、`transcript-prefs.json`。

## 开发启动

```powershell
# 终端 1 — 仓库根
.\run.ps1

# 终端 2 — 客户端（独立窗口）
cd desktop\windows
.\check-build-env.ps1   # 首次
.\run.ps1
```

根目录 `run.ps1` 等价于 macOS `./run.sh`：`.venv`、依赖、`server/main.py`。

## 设置与界面

| 位置 | 行为 |
|------|------|
| 托盘 · 开始/停止悬浮字幕 | 启动/停止 WebSocket + WASAPI 采集 |
| 托盘 · 设置 | 打开设置窗 |
| 托盘 · 打开字幕记录 | 资源管理器打开 `transcripts\` |
| 设置 → 引擎 | ASR / 翻译 / 润色 / 观看场景 |
| 设置 → 本地模型 | Whisper / Argos（cloud 变体隐藏 Tab） |
| 设置 → 字幕记录 | 目录、模板、格式、转换已有文件 |
| 设置 → 接口密钥 | 云端 API，测试与保存 |
| 悬浮 · 记 | 记录开关（与设置同步） |
| 悬浮 · EN / 背景 / 文字 | 同 macOS |

## WebSocket 协议

与 macOS 相同。发送 config（JSON）后发送 PCM；接收 `asrReady`、`asr`、`error`。

```json
{
  "type": "config",
  "sampleRate": 48000,
  "inputMode": "audio",
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "reviseMode": "speech"
}
```

## 系统音频采集

- **WASAPI loopback**（捕获系统播放声，非麦克风）
- 实现：`Capture/SystemAudioCapture.cs`（NAudio）
- 输出：48 kHz mono Int16 LE，与 macOS 协议一致

## 打包

| 脚本 | 产物 |
|------|------|
| `build-app.ps1 cloud` | `dist/VoiceBridgeAI-Cloud/` + `VoiceBridgeAI-Cloud.zip` |
| `build-app.ps1 local` | 内置 Whisper + Argos + Windows venv + zip |

```powershell
cd desktop\windows
.\build-app.ps1 cloud
.\build-app.ps1 local
.\build-app.ps1 cloud -SkipZip
```

| 变量 | 说明 |
|------|------|
| `SKIP_VENV=1` | 跳过 venv（包无法独立运行） |
| `SKIP_MODELS=1` | local 变体跳过模型下载 |
| `BUNDLE_COPY_VENV=0` | 强制新建 venv |
| `VOICEBRIDGE_MODELS_SOURCE` | 复制已有 `models/` |
| `BUNDLE_DEMO_SECRETS=1` | cloud 版合并 `.env` 密钥 |

内置布局：`server/`、`python-venv/`、`run-server.ps1`、`bundle-seed.env`、`bundle-variant.txt`。

## 编译与运行环境

### 仅用 dotnet CLI

- 工程：`EnableMsixTooling=true` + `WindowsPackageType=None`（unpackaged）
- 需要 **.NET 8 SDK**（见仓库 `global.json`）
- 若 PRI/MSBuild 报错，可装 VS 2022 Build Tools →「Windows 应用程序开发」

### Smart App Control / 未签名 exe

- `run.ps1` 优先 **`dotnet exec VoiceBridgeAI.dll`**，减少 apphost 拦截
- 开发机可对 `bin` 目录 **Unblock-File** 或添加 Defender 排除项
- 正式分发需 Authenticode 签名

### 闪退 / 0xE0434352

1. 安装 [Windows App Runtime 1.6 x64](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads)
2. 日志：`%LOCALAPPDATA%\VoiceBridgeAI\client-startup.log`

```powershell
Get-ChildItem -Recurse desktop\windows\VoiceBridgeAI | Unblock-File
```

## 参考

- Windows 源码：[desktop/windows/README.md](../desktop/windows/README.md)
- macOS 对照：[desktop/macos/Sources/VoiceBridgeAI/](../desktop/macos/Sources/VoiceBridgeAI/)
- 引擎 API：[server/README.md](../server/README.md)
- 架构：[architecture.md](architecture.md)
