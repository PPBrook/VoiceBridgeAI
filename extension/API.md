# VoiceBridgeAI 扩展 ↔ 服务端 API 契约

扩展客户端仅依赖以下接口。服务端版本变更时应保持向后兼容，或更新扩展 `manifest.json` 中的 `version`。

默认基址：`http://127.0.0.1:8765`（可配置，WebSocket 与 HTTP 同 host）。

---

## `GET /api/health`

**用途：** 连接检测；填充引擎下拉框。

**响应 200 JSON（扩展使用的字段）：**

```json
{
  "asrModes": [{ "id": "local", "label": "本地 Whisper" }],
  "partialProviders": [{ "id": "argos", "label": "Argos 离线" }],
  "finalProviders": [{ "id": "argos", "label": "Argos 离线" }, { "id": "none", "label": "不翻译（沿用句中）" }],
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "engineRules": {
    "llmProviders": ["qiniu", "aliyun", "deepseek", "openai"]
  }
}
```

扩展忽略其余字段（`version`、`cloud` 等）。

---

## `POST /api/engine/settings`

**用途：** 弹窗保存引擎时同步到服务端（并写入服务端 `.env`）。

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

扩展不解析响应体；服务端离线时扩展仍保存本地 `chrome.storage.sync`。

---

## `WebSocket /ws`

**URL：** `ws://{host}/ws`（HTTPS 基址时用 `wss://`）

### 客户端 → 服务端

**首条文本消息（连接后）：**

```json
{
  "type": "config",
  "sampleRate": 48000,
  "asrMode": "local",
  "asrProvider": "local",
  "partialProvider": "argos",
  "finalProvider": "argos",
  "reviseMode": "balanced"
}
```

**后续：** 二进制帧，Int16 PCM mono（由 `pcm-processor.js` AudioWorklet 产生）。

### 服务端 → 客户端

| `type` | 说明 | 关键字段 |
|---|---|---|
| `asrReady` | 握手完成 | — |
| `error` | 致命错误 | `message` |
| `asr` | 字幕片段 | `segmentId`, `text`, `translation`, `partial`, `final` |

`background.js` 将 `asr` 转发给内容脚本为 `{ type: "subtitle", ... }`。

---

## 兼容性

- 扩展 `0.1.x` 对应 VoiceBridgeAI 服务端 main 分支（multi-provider 引擎）
- 云端密钥管理不在扩展内，由 Web `/config` 负责
