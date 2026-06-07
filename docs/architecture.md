# 架构

## 数据流

```mermaid
flowchart LR
  subgraph macOS
    SC[ScreenCaptureKit]
    App[Swift App]
    OV[悬浮字幕 Overlay]
  end
  subgraph Sidecar
    WS[WebSocket /ws]
    ASR[ASR]
    PT[句中翻译 partial]
    FT[句末润色 final]
    RV[修订 revise]
  end
  SC --> App
  App -->|PCM 16k| WS
  WS --> ASR
  ASR --> PT
  PT --> OV
  ASR --> FT
  FT --> RV
  RV --> OV
```

## 两层配置

| 类型 | 存储 | 用途 |
|------|------|------|
| API 密钥 | `.env` | 实际调用各厂商 |
| UI 隐藏偏好 | `cloud-ui.json` + UserDefaults | 卡片显示与启动测试过滤 |

开发模式数据目录为**仓库根**（同时存在 `run.sh` 与 `server/main.py`）。  
App 模式为 `~/Library/Application Support/VoiceBridgeAI/`。

## 引擎三层

1. **ASR** — Whisper（本地）/ 腾讯 / OpenAI
2. **句中翻译** — partial provider（TMT、百度、Argos 等）
3. **句末润色** — final provider（LLM 或同 partial）

本地模型默认须在 App 内下载（`VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=1` 时可跳过预装检查）。

## 分支

- `main`：macOS App + Python sidecar（当前默认）
- `legacy/web-only`：浏览器版备份
- `feat/macapp`：App 功能开发分支

## 本地模型存储

| 模型 | 标记文件 | 数据 |
|------|----------|------|
| Whisper | `models/whisper/.installed-{规格}` | `models/hf/hub/`（HF 缓存） |
| Argos | `models/argos/.installed-en-zh` | Argos 包目录（`~/.local/share/argos-translate/packages`） |

可选模式下以 marker 为准判断 App 内「已安装」；删除时同步清理缓存并刷新 Argos 语言列表。
