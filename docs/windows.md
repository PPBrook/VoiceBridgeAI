# Windows 客户端开发（feat/winapp）

## 原则

与 `feat/macapp` 相同：**原生 UI 壳 + 复用 `server/` 引擎**，不重写 ASR/翻译/WebSocket 逻辑。

```
WASAPI 环回 (PCM 48k mono)
        ↓
Windows 客户端 (C# / WinUI)
        ↓  ws://127.0.0.1:8765/ws
server/  （与 macOS 共用）
        ↓
悬浮字幕 Overlay
```

## 阶段规划

| 阶段 | 内容 |
|------|------|
| **0** | `run.ps1`、Windows `APPDATA` 路径、文档与分支 |
| **1** | WinUI 托盘 + 启动/停止 + `ServerManager` 等价物 |
| **2** | WebSocket 会话 + 最小悬浮字幕（仅中文） |
| **3** | WASAPI 系统音频采集 |
| **4** | 设置窗（引擎 / 云端密钥），对齐 REST API |
| **5** | 本地模型 Tab、字幕记录、Cloud/Local 打包变体 |

## 数据目录

| 场景 | 路径 |
|------|------|
| 开发（仓库含 `run.ps1`） | 仓库根目录 |
| 安装版标准 | `%APPDATA%\VoiceBridgeAI\` |
| Cloud 变体 | `%APPDATA%\VoiceBridgeAI-Cloud\` |
| Local 变体 | `%APPDATA%\VoiceBridgeAI-Local\` |

`.env`、`cloud-ui.json`、`server.log`、`models/` 与 macOS 布局相同。

## 引擎启动（Windows）

```powershell
# 仓库根目录
.\run.ps1
```

等价于 macOS 的 `./run.sh`：创建 `.venv`、安装依赖、运行 `server/main.py`。

## WebSocket 协议（与 macOS 相同）

**发送 config（文本 JSON）：**

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

**发送音频：** 二进制 PCM Int16 LE，mono，48 kHz。

**接收：** `asrReady`、`asr`（含 `text`、`translation`、`partial`、`final`）、`error`。

## 系统音频采集（计划）

- API：**WASAPI loopback**（捕获系统播放声，非麦克风）
- 库候选：NAudio、` CSCore`，或 P/Invoke `IAudioClient`
- 输出格式与 macOS 对齐：48 kHz，mono，Int16，再按现有协议发送

## 悬浮字幕（计划）

- 无边框、置顶、透背景
- WinUI 3 `Window` + `ExtendsContentIntoTitleBar` / 透明 Acrylic，或 Win32 `WS_EX_LAYERED`
- 行为对齐 `OverlayPanelController`：2 行字幕、透明度、EN 开关、静音清屏

## 打包（计划）

镜像 macOS：

| 脚本 | 产物 |
|------|------|
| `build-app.ps1 cloud` | `VoiceBridgeAI-Cloud/` 目录或 zip |
| `build-app.ps1 local` | 内置 Whisper + Argos + Windows venv |

内置布局：`server/`、`python-venv/`、`run-server.ps1`、`bundle-seed.env`。

## 参考

- macOS 实现：`desktop/macos/Sources/VoiceBridgeAI/`
- 引擎 API：`server/README.md`
- 架构：`docs/architecture.md`
