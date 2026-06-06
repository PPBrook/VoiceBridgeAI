# 架构

## 总览

```
┌─────────────────────────────────────────────────────────┐
│  macOS App (Swift)                                       │
│  ScreenCaptureKit · Overlay · Settings · SidecarLaunch   │
└───────────────────────────┬─────────────────────────────┘
                            │ HTTP / WebSocket (127.0.0.1:8765)
┌───────────────────────────▼─────────────────────────────┐
│  Python server/                                          │
│  FastAPI · ASR · partial/final translate · revise · VAD  │
└───────────────────────────┬─────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              ▼             ▼             ▼
         Whisper       腾讯云/OpenAI    Argos / TMT / LLM …
         (本地可选)      (云端 ASR)      (句中 / 句末)
```

## 三层引擎

| 层 | 作用 | 典型选项 |
|----|------|----------|
| ASR | 英文语音 → 文本 | Whisper、腾讯云、OpenAI |
| 句中 (partial) | 流式快译 | Argos、TMT、各 LLM |
| 句末 (final) | 润色定稿 | Argos、none、LLM |

纠正模式（revise）在 VAD 分句基础上做回溯修正。

## 部署模式

### 独立 App（feat/macapp）

- 侧车位于 `.app/Contents/Resources/`
- 配置：`~/Library/Application Support/VoiceBridgeAI/.env`
- 本地模型：`…/models/`（按需下载）

### 开发模式

- 侧车：仓库根 `./run.sh` → `server/main.py`
- 配置：仓库根 `.env`
- App：`desktop/macos/run.sh`

## 协议

WebSocket `/ws`：握手 `config` → 二进制 PCM 或 caption JSON → 字幕 JSON 回传。

详见 [docs/websocket-api.md](../docs/websocket-api.md)。

## 归档组件

浏览器扩展 + Web 控制台见 [web-legacy.md](web-legacy.md)。
