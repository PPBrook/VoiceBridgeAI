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
| **1** | WinUI 托盘 + 启动/停止 + `ServerManager` 等价物（已完成） |
| **2** | WebSocket 会话 + 最小悬浮字幕（已完成） |
| **3** | WASAPI 系统音频采集（已完成） |
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

## 仅用 dotnet CLI 编译（无 Visual Studio）

WinUI 项目在 `dotnet build` 时若报 `ExpandPriContent` / `Microsoft.Build.Packaging.Pri.Tasks.dll` 找不到：

- 工程已设 **`EnableMsixTooling=true`** + **`WindowsPackageType=None`**（仍是 unpackaged 运行，只是借用 WinApp SDK 自带的 dotnet 兼容构建任务）
- 需要 **.NET 8 SDK**，不必装完整 Visual Studio
- 若仍失败，可装 [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/) → 工作负载 **「Windows 应用程序开发」**

**「应用程序控制策略已阻止此文件」/ Smart App Control：**

- `desktop\windows\run.ps1` 已改为 **`dotnet exec VoiceBridgeAI.dll`**（绕过未签名 apphost exe）
- 若仍被拦：**设置 → 隐私和安全性 → Windows 安全中心 → 应用和浏览器控制 → 智能应用控制 → 关**（需重启）

## 开发机：未签名被 SmartScreen 拦截

本地 `dotnet run` / `bin\...\VoiceBridgeAI.exe` **没有 Authenticode 签名**，Windows 可能提示「未知发布者」或 Defender 隔离。

**允许运行（仅自己的开发机）：**

1. SmartScreen 蓝屏 → **更多信息** → **仍要运行**
2. 或对仓库解除「来自 Internet 的锁定」：

```powershell
cd C:\Users\pengp\VoiceBridgeAI
Get-ChildItem -Recurse desktop\windows\VoiceBridgeAI | Unblock-File
```

3. **Windows 安全中心** → 病毒和威胁防护 → 管理设置 → 排除项 → 添加文件夹  
   `C:\Users\pengp\VoiceBridgeAI\desktop\windows\VoiceBridgeAI\VoiceBridgeAI\bin`

4. 若 exe 已被隔离：安全中心 → 保护历史记录 → 还原/允许

正式对外发布需购买代码签名证书并签名 exe；评审/自用开发可不上签名。

**闪退 / 退出码 `-532462766`（0xE0434352）：**

1. 安装 [Windows App Runtime 1.6 x64](https://learn.microsoft.com/windows/apps/windows-app-sdk/downloads)（与 WinApp SDK 1.6 匹配）
2. 查看日志：`%LOCALAPPDATA%\VoiceBridgeAI\client-startup.log`
3. 若弹出错误对话框，按提示处理（常见为 Runtime 未装或 Bootstrap 失败）

## 参考

- macOS 实现：`desktop/macos/Sources/VoiceBridgeAI/`
- 引擎 API：`server/README.md`
- 架构：`docs/architecture.md`
