# VoiceBridgeAI

AI 同声传译助手 — 实时将英文音频翻译为中文双语字幕。

**议题：** 七牛云 × XEngineer 暑期实训营 · 题目二 · AI 同声传译助手

## 功能

- FastAPI 服务 + `/api/health`
- Chrome / Edge 标签页音频捕获（`getDisplayMedia`）
- WebSocket 实时传输 PCM
- **识别引擎（2 项）**：腾讯云流式 ASR / 本地 Whisper
- **翻译引擎（3 项）**：双引擎（TMT+七牛）/ Argos 离线 / Google 在线
- 整句 **revise**：同一句识别/翻译变化时字幕原地更新

## 推荐演示路径

| 路径 | 识别 | 翻译 | 适用 |
|------|------|------|------|
| **A 云端（推荐）** | 腾讯云 ASR | 双引擎 | 有 Key，流式 + 润色 |
| **B 全本地** | 本地 Whisper | Argos 离线 | 无 Key，完全离线 |
| **C 兜底** | 本地 Whisper | Google 在线 | 仅联网，无 Key |

## 架构

**路径 A — 腾讯云 + 双引擎翻译**

```
Chrome PCM → 腾讯云 ASR（流式 partial/final）
  → 腾讯 TMT（句中草稿）→ 七牛 LLM（句末润色）→ 双语字幕 revise
```

**路径 B — 全本地**

```
Chrome PCM → VAD → Whisper tiny.en → Argos 离线翻译 → 双语字幕 revise
```

## 快速启动

```bash
cp .env.example .env
chmod +x run.sh && ./run.sh
```

浏览器（**Chrome**）：[http://127.0.0.1:8765](http://127.0.0.1:8765)

### 路径 A（评委演示）

`.env` 填入腾讯云 ASR/TMT 与七牛 LLM 密钥：

```env
ASR_MODE=tencent
TRANSLATE_MODE=dual
```

### 路径 B（全本地）

```env
ASR_MODE=local
TRANSLATE_MODE=argos
```

首次会下载 Whisper 与 Argos 语言包。

### 验证

```bash
curl -s http://127.0.0.1:8765/api/health | python3 -m json.tool
```

## 引擎设置

页面 **「引擎设置」** 两个下拉框（捕获前可选，捕获中锁定）：

**识别**

| ID | 说明 |
|----|------|
| `tencent` | 腾讯云流式 ASR，低延迟 |
| `local` | 本地 Whisper tiny.en |

**翻译**

| ID | partial | final |
|----|---------|-------|
| `dual` | 腾讯 TMT | 七牛 LLM |
| `argos` | Argos 离线 | Argos 离线 |
| `local` | Google | Google |

切换：

```bash
curl -X POST http://127.0.0.1:8765/api/engine/settings \
  -H "Content-Type: application/json" \
  -d '{"asrMode":"local","translateMode":"argos"}'
```

## 手动启动

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd server && python main.py
```

## 第三方依赖

| 依赖 | 用途 |
|------|------|
| FastAPI / Uvicorn | 服务 |
| faster-whisper | 本地 ASR |
| 腾讯云 ASR / TMT | 流式识别与机器翻译 |
| 七牛 AI API | LLM 句末润色 |
| argostranslate | Argos 离线翻译 |
| deep-translator | Google 在线兜底 |

## 原创部分

- 标签页音频捕获（`static/js/capture.js`）
- 双引擎选择与 WebSocket 协议（`static/js/app.js`、`server/main.py`）
- Revise 调度（`server/revise.py`）
- 腾讯云 ASR 流式转发（`server/tencent_asr.py`）
- 本地 Whisper + VAD（`server/whisper_asr.py`、`server/vad.py`）
- 翻译路由（`server/translate_config.py`、`server/translate*.py`）

## 常见问题

**必须用 Chrome 吗？** 标签页音频请用 Chrome / Edge 桌面版。

**地址** 请用 [http://127.0.0.1:8765](http://127.0.0.1:8765)。

**无 Key 怎么演示？** 识别选本地 Whisper，翻译选 Argos 或 Google。

**双引擎不显示？** 需同时配置腾讯云 Secret 与 `QINIU_AI_API_KEY`。

**腾讯云 ASR 握手失败？** 检查 AppId、SecretId、SecretKey 及语音识别是否已开通。

**SOCKS proxy 报错？** `unset ALL_PROXY HTTPS_PROXY HTTP_PROXY` 后重启，或改用全本地路径。
