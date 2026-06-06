# VoiceBridgeAI

Chrome 标签页英文内容 → 实时中文悬浮字幕。支持 **语音识别** 与 **YouTube 英文字幕** 两条输入路径。Web 控制台 + Chrome 扩展。

## 快速开始

```bash
cp .env.example .env    # 可选；全本地可不填 Key
./run.sh
```

打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)（端口见 `VOICEBRIDGE_PORT`）。

## 两种输入方式

| 方式 | 适用场景 | 入口 |
|---|---|---|
| **语音识别** | 任意带英文音频的页面 | Web `/` 或扩展「语音识别（音频）」 |
| **YouTube 英文字幕** | YouTube 已开 CC 英文字幕 | **仅扩展**「YouTube 英文字幕」 |

```
语音识别：  音频 → ASR（Whisper/腾讯云…）→ 句中翻译 → 句末润色 → 字幕
字幕模式：  YouTube CC 文本 ──────────────→ 句中翻译 → 句末润色 → 字幕
                                              ↑ 跳过 ASR
```

- **纯 Web 控制台**无法读取其他网站的字幕 DOM，只能走语音识别。
- **Chrome 扩展**可在 YouTube 上抓取 CC 文本，分句更准、延迟更低、不占用 Whisper。

## 页面

| 路径 | 用途 |
|---|---|
| `/` | 引擎设置 + 标签页音频捕获（语音识别） |
| `/config` | 云端密钥：保存 → 写入 `.env` → 测试 |
| `/guide/provider-keys` | 各接口官网与密钥说明（HTML） |

## 推荐流程

### A. 离线试用（语音识别）

1. `./run.sh` → 打开 `/`，默认 `Whisper + Argos + Argos`
2. 捕获标签页音频（需勾选「分享标签页音频」）

### B. YouTube 字幕模式（扩展，推荐有 CC 时）

1. `./run.sh` → `chrome://extensions` 加载 `extension/`
2. 打开 YouTube 视频，开启 **CC → English**
3. 扩展弹窗：**英文来源** → `YouTube 英文字幕` → **开始**（徽章 **CC**）
4. 句中/句末可改为云端接口（见下），不必离线

### C. 云端引擎

1. `/config` 填 Key → **保存** → **测试**（悬停状态看详情）
2. 扩展或 `/` 选三层组合；句中推荐 MT，句末推荐 LLM（见 `/guide/provider-keys` 与各接口说明）

## 三层引擎

| 层 | 语音识别模式 | YouTube 字幕模式 |
|---|---|---|
| **识别** | Whisper / 腾讯云 / OpenAI | **跳过**（直接用 CC 文本） |
| **句中** | Argos 离线 或 TMT / LLM 快译… | 同上，可云端 |
| **句末** | Argos / **不翻译** / LLM 润色… | 同上，可云端 |

- 离线默认可用项（Whisper、Argos 等）**无需**在 `/config` 测试。
- 云端接口：**测试通过**后才出现在下拉框；`VERIFIED_*` 在进程内生效，重启后靠自动测试或手动一键测试。
- OpenAI：**识别**测试只验 Key；**句中/句末**走 Chat，需账户有余额（429 = 配额不足）。

## 项目结构

```
server/
  main.py                 FastAPI + WebSocket（含 caption-mode）
  provider_registry.py    接口 ID / 组合规则
  provider_enable.py      测试门控 + 离线默认可用
  engine_config.py        三层引擎统一状态
  translate_*.py          各厂商适配
static/
  index.html, config.html
  js/app.js, config.js, engine-select.js, capture.js
extension/                Chrome 扩展（见 extension/README.md）
  content/youtube-captions.js   YouTube CC 抓取
```

## 环境变量（`.env`）

复制 `.env.example`。密钥与 `/config` 表单一一对应；**保存配置**会合并写入 `.env`。

引擎字段（控制台或扩展改引擎时也会写入）：

- `ASR_PROVIDER` / `PARTIAL_PROVIDER` / `FINAL_PROVIDER` / `REVISE_MODE`

其他：`VOICEBRIDGE_PORT`（默认 `8765`）、`AUTO_TEST_ON_START=1`

## API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 健康检查、引擎选项、已验证接口 |
| GET | `/api/cloud/settings` | 云端配置状态 |
| POST | `/api/cloud/settings` | 保存密钥 → `.env` |
| POST | `/api/cloud/test` | 测试单项 |
| POST | `/api/cloud/test-all` | 一键测试 |
| POST | `/api/engine/settings` | 保存引擎 → 内存 + `.env` |
| WS | `/ws` | 音频 PCM **或** 字幕 JSON（见 [extension/API.md](extension/API.md)） |

WebSocket 字幕模式：`config` 带 `inputMode: "caption"`，后续发 `{ type: "caption", text, segmentId, final }`。

## Chrome 扩展

扩展位于本仓库 **`extension/`** 目录（与服务端同一仓库）。

1. `./run.sh`
2. `chrome://extensions` → 加载 **`extension/`**（详见 [extension/README.md](extension/README.md)）
3. 选 **英文来源** + 句中/句末引擎 → **开始悬浮字幕**

| 模式 | 徽章 | 说明 |
|---|---|---|
| 语音识别 | `ON` | 采集标签页音频，走 ASR |
| YouTube 字幕 | `CC` | 读 CC 文本，不抓音频、不跑 Whisper |

默认引擎：`local + argos + argos`（可改为云端翻译）。API 契约：[extension/API.md](extension/API.md)。
