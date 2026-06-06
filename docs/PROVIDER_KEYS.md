# 各接口官网与密钥说明

> **默认可选（无需配置）：** 本地 Whisper（识别）、Argos（句中/句末）— 直接在引擎设置选用。  
> **阅读版：** [http://127.0.0.1:8765/guide/provider-keys](http://127.0.0.1:8765/guide/provider-keys)

在 Web 控制台 **接口配置** 中填写云端字段 → **保存** → **测试**（或 **一键测试全部**）。  
`.env` 变量名与表单字段一一对应，见 `.env.example`。

---

## 本地 / 离线（默认可选，不在接口配置面板）

以下接口启动后即在引擎下拉框中可用，**无需 Key、无需测试**。

### 本地 Whisper（识别）

| 项目 | 说明 |
|---|---|
| **能力** | 语音识别（ASR） |
| **官网** | [OpenAI Whisper（开源）](https://github.com/openai/whisper) |
| **密钥** | **无需** |
| **环境变量** | `WHISPER_MODEL`（默认 `base.en`）、`WHISPER_DEVICE`（默认 `cpu`） |
| **备注** | 首次测试/运行会下载模型；纯 CPU 较慢，适合离线演示 |

### Argos 离线（句中 / 句末）

| 项目 | 说明 |
|---|---|
| **能力** | 句中翻译、句末润色（英→中） |
| **官网** | [Argos Translate](https://github.com/argosopentech/argos-translate) |
| **密钥** | **无需** |
| **备注** | 首次测试会下载语言包；质量一般，适合无网环境 |

---

## 国内接口

### 腾讯云（识别 + TMT 翻译）

| 项目 | 说明 |
|---|---|
| **能力** | 识别（流式 ASR）、句中/句末（机器翻译 TMT） |
| **官网** | [腾讯云](https://cloud.tencent.com/) |
| **控制台** | [语音识别 ASR](https://console.cloud.tencent.com/asr) · [机器翻译 TMT](https://console.cloud.tencent.com/tmt) · [API 密钥](https://console.cloud.tencent.com/cam/capi) |
| **文档** | [实时语音识别](https://cloud.tencent.com/document/product/1093) · [文本翻译](https://cloud.tencent.com/document/product/551) |
| **必填密钥** | `TENCENT_ASR_APP_ID` — ASR 应用 AppId<br>`TENCENT_ASR_SECRET_ID` — API 密钥 SecretId<br>`TENCENT_ASR_SECRET_KEY` — API 密钥 SecretKey |
| **可选** | `TENCENT_ASR_ENGINE`（默认 `16k_en`）<br>`TMT_REGION`（如 `ap-guangzhou`）<br>`TMT_PROJECT_ID`（默认 `0`） |
| **备注** | ASR 与 TMT **共用同一对 SecretId/SecretKey**；识别与 TMT 需在控制台分别开通 |

### 七牛 AI（句中 / 句末 LLM）

| 项目 | 说明 |
|---|---|
| **能力** | 句中快译、句末润色（OpenAI 兼容 Chat API） |
| **官网** | [七牛 AI 大模型](https://www.qiniu.com/ai) |
| **控制台** | [API Key 管理](https://portal.qiniu.com/ai-inference/api-key) · [模型广场](https://www.qiniu.com/ai/models) |
| **文档** | [实时推理 API](https://developer.qiniu.com/aitokenapi/13379/real-time-ai-interface-api) |
| **必填密钥** | `QINIU_AI_API_KEY` |
| **可选** | `QINIU_AI_BASE_URL`（默认 `https://api.qnaigc.com/v1`）<br>`QINIU_AI_MODEL`（须与模型广场 API 参数一致，如 `qwen-turbo`、`deepseek-v3`） |
| **备注** | 新用户通常有免费额度；模型 ID 填错会测试失败 |

### 阿里云 DashScope（句中 / 句末 LLM）

| 项目 | 说明 |
|---|---|
| **能力** | 句中快译、句末润色（OpenAI 兼容模式） |
| **官网** | [百炼 / Model Studio](https://dashscope.aliyun.com/) |
| **控制台** | [API Key](https://bailian.console.aliyun.com/?tab=model#/api-key) |
| **文档** | [获取 API Key](https://help.aliyun.com/zh/model-studio/get-api-key) |
| **必填密钥** | `ALIYUN_AI_API_KEY` |
| **可选** | `ALIYUN_AI_BASE_URL`（默认 DashScope 兼容地址）<br>`ALIYUN_AI_MODEL`（如 `qwen-turbo`） |

### 百度翻译（句中 / 句末）

| 项目 | 说明 |
|---|---|
| **能力** | 句中、句末机器翻译 |
| **官网** | [百度翻译开放平台](https://fanyi-api.baidu.com/) |
| **控制台** | [管理控制台](https://fanyi-api.baidu.com/manage/developer) — 创建「通用翻译 API」应用 |
| **文档** | [接入文档](https://fanyi-api.baidu.com/doc/21) |
| **必填密钥** | `BAIDU_APP_ID` — 应用 ID<br>`BAIDU_SECRET_KEY` — 密钥（注意不是 AppSecret 的旧称混淆，以控制台为准） |
| **备注** | 标准版有免费额度；需实名认证 |

### DeepSeek（句中 / 句末 LLM）

| 项目 | 说明 |
|---|---|
| **能力** | 句中快译、句末润色 |
| **官网** | [DeepSeek 开放平台](https://www.deepseek.com/) |
| **控制台** | [API Keys](https://platform.deepseek.com/api_keys) |
| **文档** | [API 文档](https://platform.deepseek.com/api-docs/) |
| **必填密钥** | `DEEPSEEK_API_KEY` |
| **可选** | `DEEPSEEK_BASE_URL`（默认 `https://api.deepseek.com/v1`）<br>`DEEPSEEK_MODEL`（默认 `deepseek-chat`） |

---

## 海外接口

### OpenAI（识别 + 句中 / 句末 LLM）

| 项目 | 说明 |
|---|---|
| **能力** | 识别（Whisper API）、句中快译、句末润色 |
| **官网** | [OpenAI Platform](https://platform.openai.com/) |
| **控制台** | [API Keys](https://platform.openai.com/api-keys) |
| **文档** | [Whisper](https://platform.openai.com/docs/guides/speech-to-text) · [Chat Completions](https://platform.openai.com/docs/api-reference/chat) |
| **必填密钥** | `OPENAI_API_KEY` — 识别与翻译**共用** |
| **可选** | `OPENAI_BASE_URL`（默认官方地址；可填代理）<br>`OPENAI_MODEL`（翻译，默认 `gpt-4o-mini`）<br>`OPENAI_ASR_MODEL`（识别，默认 `whisper-1`） |
| **备注** | 需海外网络或可用代理；按量计费 |

### DeepL（句中 / 句末）

| 项目 | 说明 |
|---|---|
| **能力** | 句中、句末机器翻译 |
| **官网** | [DeepL API](https://www.deepl.com/pro-api) |
| **控制台** | [DeepL Account](https://www.deepl.com/your-account/keys) |
| **文档** | [API 文档](https://www.deepl.com/docs-api) |
| **必填密钥** | `DEEPL_API_KEY` |
| **可选** | `DEEPL_API_URL` — 免费版 Key 以 `:fx` 结尾时用 `https://api-free.deepl.com/v2/translate`；Pro 用 `https://api.deepl.com/v2/translate` |
| **备注** | 免费 API 有字符限额；国内直连可能不稳定 |

### Google 在线（句中 / 句末）

| 项目 | 说明 |
|---|---|
| **能力** | 句中、句末翻译（非官方 Cloud API，经 `deep-translator` 访问网页翻译） |
| **官网** | [Google 翻译](https://translate.google.com/) |
| **密钥** | **无需** |
| **备注** | 需能访问 Google；无 SLA，仅适合兜底/测试，生产环境建议用 Cloud Translation API（本项目未接入） |

---

## 快速对照表

| 接口 | 识别 | 句中 | 句末 | 是否需要 Key |
|---|---|---|---|---|
| 本地 Whisper | ✅ | — | — | 否 |
| 腾讯云 ASR | ✅ | — | — | 是（AppId + SecretId/Key） |
| 腾讯 TMT | — | ✅ | ✅ | 是（同上 Secret） |
| 七牛 AI | — | ✅ | ✅ | 是（API Key） |
| 阿里云 DashScope | — | ✅ | ✅ | 是（API Key） |
| 百度翻译 | — | ✅ | ✅ | 是（AppId + Secret Key） |
| DeepSeek | — | ✅ | ✅ | 是（API Key） |
| OpenAI | ✅ | ✅ | ✅ | 是（API Key） |
| DeepL | — | ✅ | ✅ | 是（API Key） |
| Google 在线 | — | ✅ | ✅ | 否 |
| Argos | — | ✅ | ✅ | 否 |
