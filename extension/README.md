# VoiceBridgeAI 浏览器扩展

> **归档说明**：本分支（`main` / `feat/macapp`）以 macOS App 为主。浏览器版完整维护见 **`legacy/web-only`** 分支与 [docs/web-legacy.md](../docs/web-legacy.md)。

本仓库内的 **Manifest V3** 扩展：在任意网页上显示 **VoiceBridgeAI 中文悬浮字幕**。支持 **Google Chrome**、**Microsoft Edge** 及其它 Chromium 内核浏览器（需 Offscreen Document，一般 Chrome/Edge 109+）。

**与服务端：** 扩展在 `extension/`，服务端在 `server/` + `static/`。同一仓库，`./run.sh` 后加载扩展即可。

## 安装

1. 仓库根目录：`./run.sh`
2. 加载扩展（**Chrome 与 Edge 使用同一 `extension/` 目录，无需改代码**）：

   | 浏览器 | 地址 | 操作 |
   |---|---|---|
   | **Chrome** | `chrome://extensions` | 开启「开发者模式」→「加载已解压的扩展程序」→ 选 `extension/` |
   | **Edge** | `edge://extensions` | 开启「开发人员模式」→「加载扩展」→ 选 `extension/` |

3. 弹窗确认 **服务端地址**（默认 `http://127.0.0.1:8765`）
4. 选输入方式与引擎 → **开始悬浮字幕**

修改代码后请在扩展管理页 **重新加载** 扩展。

## 两种输入方式

| 英文来源 | 徽章 | 说明 |
|---|---|---|
| **语音识别（音频）** | `ON` | 采集标签页音频 → 服务端 ASR → 翻译 |
| **YouTube 英文字幕** | `CC` | 读取 YouTube CC DOM → **跳过 ASR** → 只翻译 |

### YouTube 字幕模式

1. 在 Chrome 或 Edge 打开 **youtube.com** 视频页
2. 播放器开启 **CC → English**
3. 弹窗 **英文来源** → `YouTube 英文字幕` → **开始**
4. 终端应出现 `caption ready`，不应出现 `faster_whisper`

### 语音识别模式

适用于无字幕或 B 站等站点。会占用 tab 音频通道；YouTube 有英文字幕时优先用 CC 模式。

## 配置

| 项 | 说明 |
|---|---|
| 服务端地址 | 弹窗顶部；非 localhost 需浏览器授权 |
| 英文来源 | 语音识别 / YouTube 英文字幕 |
| 句中 / 句末 | 与 Web 控制台同步；可用云端（不限于 Argos） |
| 云端密钥 | 扩展不存 Key → 弹窗 **接口配置** → `/config` |

## 与服务端通信

详见 [API.md](./API.md)：`GET /api/health`、`POST /api/engine/settings`、`WebSocket /ws`。

## 兼容性说明

- **已验证目标：** Chrome、Edge（Chromium）
- **原理：** 二者共用 Chromium 扩展 API（`tabCapture`、`offscreen`、`scripting` 等），本扩展直接调用 `chrome.*` 命名空间，Edge 同样可用
- **未支持：** Firefox（Offscreen 架构不同）、Safari（需单独打包）
- **Web 控制台：** 在 Chrome 或 Edge 打开 `http://127.0.0.1:8765` 同样可用

## 目录结构

```
extension/
├── manifest.json
├── background.js / offscreen.js
├── content/          # 悬浮字幕 + YouTube CC
├── popup/
├── pcm-processor.js
├── API.md
└── README.md
```
