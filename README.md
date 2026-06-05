# VoiceBridgeAI

AI 同声传译助手 — 实时将英文音频翻译为中文双语字幕。

**议题：** 七牛云 × XEngineer 暑期实训营 · 题目二 · AI 同声传译助手

## 功能

- FastAPI 服务 + `/api/health`
- Chrome / Edge 标签页音频捕获（`getDisplayMedia`）
- WebSocket 实时传输 PCM
- **双 ASR 引擎**（页面可切换）：
  - **腾讯云实时 ASR** — 流式英文，`16k_en`
  - **本地 Whisper** — `tiny.en`，VAD 分句，无需腾讯云
- 腾讯云模式：英文 partial 边说边出，句末定稿；识别/翻译变化时**原地修正**（`revise`）
- 本地模式：句中每 0.8s 重识别 + 翻译修正，静音后定稿
- 英译中：**partial 腾讯 TMT**（快）→ **final 七牛 LLM**（润色）；未配置时回退 Google

## 架构

**腾讯云模式（`asrMode=tencent`）**

```
Chrome PCM → WebSocket /ws → 重采样 16kHz → 腾讯云 ASR（流式）
  → partial / final 英文 → Google 翻译（句末）→ 双语字幕
```

**本地模式（`asrMode=local`）**

```
Chrome PCM → WebSocket /ws → VAD 静音分句 → Whisper tiny.en
  → 英文 → Google 翻译 → 双语字幕
```

## 快速启动

### 方式 A：仅本地 Whisper（最简单）

无需腾讯云，适合先跑通流程：

```bash
cp .env.example .env
# .env 中保持 ASR_MODE=local 即可，可不填腾讯云密钥

./run.sh
```

浏览器（**Chrome**）：[http://127.0.0.1:8765](http://127.0.0.1:8765)

页面 **ASR 设置** → 选「本地 Whisper（无需腾讯云）」→ 捕获音频。

首次启动会下载 `Systran/faster-whisper-tiny.en`（约 75MB）。

### 方式 B：使用腾讯云实时 ASR

1. 开通 [语音识别](https://console.cloud.tencent.com/asr)
2. [API 密钥管理](https://console.cloud.tencent.com/cam/capi) 获取 `SecretId` / `SecretKey`
3. 记录账号 **AppId**（数字）

```bash
cp .env.example .env
```

编辑 `.env`：

```env
TENCENT_ASR_APP_ID=你的AppId
TENCENT_ASR_SECRET_ID=AKID...
TENCENT_ASR_SECRET_KEY=...
TENCENT_ASR_ENGINE=16k_en
ASR_MODE=tencent
```

```bash
./run.sh
```

### 验证

```bash
curl -s http://127.0.0.1:8765/api/health | python3 -m json.tool
```

示例字段：

```json
{
  "asrMode": "local",
  "asrModes": [...],
  "tencentConfigured": false,
  "whisperModel": "tiny.en",
  "asrEngine": "tiny.en"
}
```

`./run.sh` 会自动加载项目根目录 `.env`（已在 `.gitignore`，勿提交密钥）。

## ASR 引擎选择

页面 **「ASR 设置」** 下拉框（捕获前可改，捕获中锁定）：

| 模式 | ID | 说明 |
|------|-----|------|
| 腾讯云实时 ASR | `tencent` | 流式、延迟低；需 `.env` 密钥 |
| 本地 Whisper | `local` | `tiny.en` + VAD；无需腾讯云 |

| 环境变量 | 说明 | 默认 |
|----------|------|------|
| `ASR_MODE` | `tencent` 或 `local` | 有腾讯云密钥 → `tencent`，否则 → `local` |
| `TENCENT_ASR_ENGINE` | 腾讯云引擎，如 `16k_en`、`16k_en_large` | `16k_en` |

切换引擎可调用：

```bash
curl -X POST http://127.0.0.1:8765/api/asr/settings \
  -H "Content-Type: application/json" \
  -d '{"asrMode":"local"}'
```

## 翻译双引擎

| 阶段 | 引擎 | 环境变量 |
|------|------|----------|
| partial（句中草稿） | 腾讯 TMT | 与 ASR 共用 `TENCENT_ASR_SECRET_*` |
| final（句末定稿） | 七牛 LLM | `QINIU_AI_API_KEY`、`QINIU_AI_MODEL` |

未配置时自动回退 Google（`deep-translator`）。`/api/health` 可见 `translatePartial` / `translateFinal`。

## 手动启动

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd server && python main.py
```

## 第三方依赖

| 依赖 | 用途 | 官网 |
|------|------|------|
| [FastAPI](https://fastapi.tiangolo.com/) | HTTP / WebSocket 服务 | fastapi.tiangolo.com |
| [Uvicorn](https://www.uvicorn.org/) | ASGI 服务器 | uvicorn.org |
| [websockets](https://websockets.readthedocs.io/) | 连接腾讯云 ASR WebSocket | websockets.readthedocs.io |
| [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | 本地 Whisper ASR | github.com/SYSTRAN/faster-whisper |
| [NumPy](https://numpy.org/) | PCM 重采样 | numpy.org |
| [deep-translator](https://github.com/nidhaloff/deep-translator) | 英译中（Google 非官方接口） | github.com/nidhaloff/deep-translator |
| [腾讯云实时语音识别](https://cloud.tencent.com/document/api/1093/48982) | 流式 ASR（可选） | cloud.tencent.com |

浏览器 API（无额外安装）：`getDisplayMedia`、`WebSocket`、`MediaStreamTrackProcessor`

运行时模型（本地模式）：Hugging Face `Systran/faster-whisper-tiny.en`

## 原创部分

以下为自主实现（非第三方库直接提供的能力）：

- 标签页音频捕获与 Chrome 适配（`static/js/capture.js`）
- PCM 采集、ASR 引擎选择与 WebSocket 协议（`static/js/app.js`、`server/main.py`）
- PCM 重采样与 200ms 分帧（`server/pcm.py`）
- ASR 模式配置（`server/asr_config.py`）
- 腾讯云 ASR 签名、流式转发与 partial/final 调度（`server/tencent_asr.py`）
- 本地 Whisper 识别（`server/whisper_asr.py`）
- RMS 静音 VAD 分句（`server/vad.py`）
- 英译中与双语字幕 UI（`server/translate.py`、`static/`）

## 常见问题

**必须用 Chrome 吗？**  
标签页音频捕获请用 **Chrome / Edge 桌面版**；不要用 Cursor 内置预览。

**地址不要用 `0.0.0.0`**  
请用 [http://127.0.0.1:8765](http://127.0.0.1:8765)，否则 `getDisplayMedia` 可能不可用。

**不想用腾讯云？**  
选「本地 Whisper」，或 `.env` 设 `ASR_MODE=local`，无需填写腾讯云密钥。

**腾讯云 ASR 握手失败？**  
检查 AppId（数字）、SecretId、SecretKey，以及是否已开通语音识别并有可用额度。

**报错 `SOCKS proxy` / `python-socks`？**  
系统 VPN/代理会干扰腾讯云 WebSocket；代码已尝试直连。仍失败时可：

```bash
unset ALL_PROXY all_proxy HTTPS_PROXY https_proxy HTTP_PROXY http_proxy
./run.sh
```

或改用 **本地 Whisper**。

**本地模式为什么比腾讯云慢？**  
本地模式等 VAD 检测到句尾静音后才跑 Whisper，无流式 partial；换腾讯云模式可边说边出英文。

**腾讯云引擎怎么换？**  
`.env` 中 `TENCENT_ASR_ENGINE`，常用 `16k_en`（快）、`16k_en_large`（准），见[官方文档](https://cloud.tencent.com/document/api/1093/48982)。
