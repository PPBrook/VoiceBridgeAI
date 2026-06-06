# WebSocket / HTTP API 契约

macOS 桌面客户端与 Python 引擎的接口约定。浏览器版见 **`legacy/web-only`** 分支。

默认基址：`http://127.0.0.1:8765`（WebSocket 与 HTTP 同 host）。

---

## `GET /api/health`

**用途：** 连接检测；填充引擎下拉框。

**响应 200 JSON（常用字段）：**

```json
{
  "asrModes": [{ "id": "local", "label": "本地 Whisper" }],
  "partialProviders": [{ "id": "argos", "label": "Argos 离线" }],
  "finalProviders": [{ "id": "argos", "label": "Argos 离线" }, { "id": "none", "label": "不翻译（沿用句中）" }],
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "localModels": [],
  "optionalLocalModels": true
}
```

---

## `POST /api/engine/settings`

**请求体：**

```json
{
  "asrMode": "local",
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "reviseMode": "balanced"
}
```

写入 `.env`（开发：仓库根；App：`~/Library/Application Support/VoiceBridgeAI/.env`）。

---

## `GET /api/models/local` · `POST /api/models/local/download`

本地模型安装状态与下载（`feat/macapp`）。见 [server/README.md](../server/README.md)。

---

## `WebSocket /ws`

**URL：** `ws://127.0.0.1:8765/ws`

### 客户端 → 服务端

**首条文本消息：**

```json
{
  "type": "config",
  "sampleRate": 48000,
  "inputMode": "audio",
  "asrMode": "local",
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "reviseMode": "balanced"
}
```

**后续：** 二进制帧，Int16 PCM mono（系统音频采集）。

### 服务端 → 客户端

| `type` | 说明 | 关键字段 |
|--------|------|----------|
| `asrReady` | 握手完成 | — |
| `error` | 致命错误 | `message` |
| `asr` | 字幕片段 | `segmentId`, `text`, `translation`, `partial`, `final` |

---

## 兼容性

- 桌面 App 与服务端同仓库 `server/` 演进
- 浏览器扩展协议见 `legacy/web-only` 分支 `extension/API.md`
