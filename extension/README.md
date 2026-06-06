# VoiceBridgeAI Chrome 扩展

本仓库内的 Chrome MV3 扩展：在任意网页上显示 **VoiceBridgeAI 中文悬浮字幕**。支持两种英文输入来源。

**与本仓库的关系：** 扩展在 `extension/`，服务端在 `server/` + `static/`。克隆本仓库后 `./run.sh` + 加载扩展即可。

## 安装

1. 仓库根目录：`./run.sh`
2. `chrome://extensions` → **开发者模式** → **加载已解压的扩展程序** → 选 **`extension/`**
3. 弹窗确认 **服务端地址**（默认 `http://127.0.0.1:8765`）
4. 选输入方式与引擎 → **开始悬浮字幕**

修改代码后请 **重新加载** 扩展。

## 两种输入方式

| 英文来源 | 徽章 | 说明 |
|---|---|---|
| **语音识别（音频）** | `ON` | 采集标签页音频 → 服务端 ASR → 翻译 |
| **YouTube 英文字幕** | `CC` | 读取 YouTube CC DOM → **跳过 ASR** → 只翻译 |

### YouTube 字幕模式（推荐有英文字幕时）

1. 打开 **youtube.com** 视频页
2. 播放器开启 **CC**，语言选 **English**
3. 弹窗 **英文来源** → `YouTube 英文字幕`
4. **开始** → 终端应出现 `caption ready`，**不应**出现 `faster_whisper`
5. 约 6 秒内无字幕时，悬浮层会提示检查 CC

### 语音识别模式

适用于无字幕的视频页。会占用 tab 音频通道；YouTube 上若已有 CC，优先用字幕模式。

## 配置

| 项 | 说明 |
|---|---|
| 服务端地址 | 弹窗顶部；非 localhost 需浏览器授权 |
| 英文来源 | 语音识别 / YouTube 英文字幕 |
| 句中 / 句末 | 与 Web 控制台同步；**可用云端**（不限于离线 Argos） |
| 纠正 | 实时优先 / 标准 / 精准 |
| 云端密钥 | 扩展不存 Key → 弹窗 **接口配置** → `/config` |

### 云端翻译（字幕模式同样适用）

1. 浏览器打开 `/config` → 填 Key → 保存 → 测试句中/句末
2. 扩展弹窗改 **句中翻译**、**句末润色**（如 TMT + 七牛 LLM）
3. 保存后自动 `POST /api/engine/settings`

测试通过的接口才会出现在下拉框。

## 与服务端通信

详见 [API.md](./API.md)。

| 接口 | 用途 |
|---|---|
| `GET /api/health` | 连接检测、引擎选项 |
| `POST /api/engine/settings` | 同步引擎 |
| `WebSocket /ws` | 音频 PCM 或 `{ type: "caption", ... }` 字幕文本 |

## 目录结构

```
extension/
├── background.js              # 编排：音频 / 字幕两路
├── offscreen.js               # WebSocket 客户端
├── content/
│   ├── subtitle-overlay.js    # 悬浮字幕 UI
│   └── youtube-captions.js    # YouTube CC 监听
├── popup/                     # 弹窗：输入源 + 引擎
├── pcm-processor.js
├── API.md
└── README.md
```

## 开发说明

- `pcm-processor.js`、`popup/engine-select.js` 为扩展内自有副本（与 `static/js/` 分开维护）
- YouTube 字幕通过 `MutationObserver` + 轮询读取 `.ytp-caption-segment`（含 Shadow DOM 深度查询）
- 纯 Web 控制台无法跨站读字幕；字幕模式为扩展专有
