# VoiceBridgeAI macOS 桌面客户端

Swift + AppKit + ScreenCaptureKit 原生客户端（无 Electron / Node）。

**定位**：本机 **UI + 系统音频采集**；**ASR / 翻译 / 纠正** 仍由仓库根目录的 Python `server/` 处理（与 Web、Chromium 扩展共用同一套服务与 API）。桌面端不是「替代服务端」，而是第四种入口。

## 功能

| 能力 | 说明 |
|------|------|
| 系统音频采集 | ScreenCaptureKit，mono int16 PCM → WebSocket |
| 悬浮字幕 | 置顶面板：双行、partial、纠正闪色、背景透明度、EN 开关 |
| 控制面板 | 连接状态、开始/停止、引擎摘要 |
| App 内设置 | 引擎（ASR / 句中 / 句末 / 纠正）+ 云端密钥，API 同 Web `/config` |
| 菜单栏 | 可收起到菜单栏；关主窗口不退出 |
| 自动拉起服务 | 若 `http://127.0.0.1:8765/api/health` 不可达，执行仓库根 `run.sh` |

## 要求

- macOS **13+**
- Xcode 或 Apple **Command Line Tools**（`swift build`）
- 仓库根目录 Python 环境可用（在根目录手动 `./run.sh` 能成功）
- **屏幕录制**权限（采系统声，非摄像头）

## 运行

推荐：

```bash
cd desktop/macos
./run.sh
```

`desktop/macos/run.sh` 会：设置 `VOICEBRIDGE_ROOT` → `swift build -c release` → 启动可执行文件。

手动：

```bash
cd desktop/macos
swift build -c release
export VOICEBRIDGE_ROOT=/path/to/VoiceBridgeAI   # 含 run.sh 的仓库根
.build/release/VoiceBridgeAI
```

可选环境变量：

| 变量 | 默认 | 说明 |
|------|------|------|
| `VOICEBRIDGE_ROOT` | 自动推断 | 仓库根（必须含 `run.sh`） |
| `VOICEBRIDGE_PORT` | `8765` | 与 Python 服务端口一致 |

首次使用：**系统设置 → 隐私与安全性 → 屏幕录制**，允许 `VoiceBridgeAI`（或当前可执行文件名）。  
当前为 **SPM 可执行文件**，非 `.app`；`swift build` 后路径变化可能导致 TCC 权限需重新授权。

## 源码结构

```
desktop/
├── README.md
└── macos/
    ├── Package.swift
    ├── run.sh
    └── Sources/VoiceBridgeAI/
        ├── VoiceBridgeAIMain.swift       # @main
        ├── AppDelegate.swift
        ├── ControlWindowController.swift # 主控制窗
        ├── SettingsWindowController.swift
        ├── EnginePanelView.swift         # 引擎 Tab
        ├── CloudPanelView.swift          # 密钥 Tab
        ├── EngineSelectGroups.swift      # 下拉分组（对齐 Web engine-select.js）
        ├── CloudProviderGuides.swift
        ├── FormBuilder.swift
        ├── SettingsStore.swift
        ├── EngineConfig.swift            # 引擎模型 + APIClient（HTTP）
        ├── SessionController.swift       # 会话：服务 → WS → 采集
        ├── WebSocketSession.swift
        ├── ServerManager.swift           # 拉起根 run.sh、health 检查
        ├── RepoRoot.swift                # VOICEBRIDGE_ROOT 解析
        ├── SystemAudioCapture.swift
        ├── ScreenCaptureAccess.swift     # 屏幕录制权限
        ├── SubtitleStore.swift
        ├── OverlayPanelController.swift
        ├── OverlayPreferences.swift      # UserDefaults：透明度、EN
        └── MenuBarController.swift
```

编译产物：`desktop/macos/.build/`（已在根 `.gitignore` 忽略）。

## 与 Chromium 扩展

| | 扩展 | macOS 桌面 |
|---|---|---|
| 音频来源 | 当前标签页 | 系统音频 |
| 字幕展示 | 网页内 overlay | 屏幕置顶窗 |
| YouTube 英文字幕 | ✅ | ❌ 未实现 |
| 服务端 | 共用 `server/` | 共用 `server/` |
| 可配置远程 serverUrl | ✅ | ❌ 仅 `127.0.0.1` |

修改引擎/纠正模式后需 **停止并重新开始字幕** 才会生效（WebSocket 握手时一次性下发配置）。

## 已知限制（MVP）

- 无 `.app` 打包 / 代码签名 / 公证
- 无 YouTube caption 模式
- 服务端地址写死本机；无 `wss://` 远程反代
- 每次冷启动仍依赖仓库根 Python（`run.sh`、venv、Whisper 等）

## 后续

- [ ] `.app` 打包（内置或隐藏 Python 侧车，实现「只装一个 App」）
- [ ] 云端-only 瘦身侧车
- [ ] Windows（WASAPI loopback）

## 故障排查

| 现象 | 处理 |
|------|------|
| 找不到 `run.sh` | 设置 `VOICEBRIDGE_ROOT` 指向仓库根 |
| 启动超时 / 退出码 1 | 检查端口 8765 是否被占用；根目录手动 `./run.sh` 看报错 |
| 无声音 / 采集失败 | 检查屏幕录制权限；重启 App 后再试 |
| 改设置不生效 | 停止字幕后重新开始 |

更多项目说明见仓库根 [README.md](../README.md)。
