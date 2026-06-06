# VoiceBridgeAI Chrome 扩展

本仓库 **VoiceBridgeAI** 内的 Chrome MV3 扩展模块：捕获当前标签页音频，在页面上显示实时中英悬浮字幕。

**与本仓库的关系：** 扩展代码在 `extension/` 目录，服务端在 `server/` + `static/`。比赛/评审使用**同一仓库**，克隆本仓库后分别启动服务端并加载扩展即可。

## 安装

1. 在仓库根目录启动服务端：`./run.sh`（见根目录 [README.md](../README.md)）
2. 打开 `chrome://extensions` → **开发者模式** → **加载已解压的扩展程序**
3. 选择本仓库下的 **`extension/`** 目录（含 `manifest.json`）
4. 在扩展弹窗确认 **服务端地址**（默认 `http://127.0.0.1:8765`）
5. 打开有英文音频的网页 → **开始悬浮字幕**

修改代码后请在 `chrome://extensions` **重新加载**扩展。

## 配置

| 项 | 说明 |
|---|---|
| 服务端地址 | 弹窗顶部输入框；非 localhost 时会请求浏览器授权 |
| 引擎 | 识别 / 句中 / 句末 / 纠正；保存后同步到服务端 |
| 云端密钥 | 扩展不存 Key → 点弹窗底部 **接口配置** 打开 Web 控制台 |

默认引擎：`local + argos + argos`（离线可用）。

## 与服务端通信

扩展只使用以下三个接口（详见 [API.md](./API.md)）：

| 接口 | 用途 |
|---|---|
| `GET /api/health` | 连接检测、引擎下拉选项 |
| `POST /api/engine/settings` | 同步引擎选择 |
| `WebSocket /ws` | 发送 PCM 音频、接收字幕 |

## 目录结构

```
extension/
├── manifest.json           # MV3 清单
├── background.js           # 捕获编排、字幕转发
├── offscreen.js            # 标签页音频 → PCM → WebSocket
├── pcm-processor.js        # AudioWorklet（本仓库自有副本）
├── content/                # 页面内悬浮字幕
├── popup/                  # 扩展弹窗 UI
│   ├── engine-select.js    # MT/LLM 分组下拉
│   └── popup.js
├── icons/
├── README.md
└── API.md                  # 服务端契约
```

## 模块说明

`extension/` 在**本仓库内自包含**（不符号链接 `static/js/`，可单独在 Chrome 中加载），但**不拆分为独立 Git 仓库**——服务端、Web 控制台与扩展均在本项目中维护。

## 开发说明

- `pcm-processor.js` 与 `popup/engine-select.js` 为扩展目录内的**自有副本**（与 `static/js/` 中 Web 控制台版本分开维护，修改时请同步或分别测试）
- 扩展与服务端通过 [API.md](./API.md) 中的三个接口通信
