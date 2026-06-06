# VoiceBridgeAI

Chrome 标签页英文音频 → 实时识别 → 中英双语字幕。含 Web 控制台与 Chrome 扩展。

## 配置流程

1. 运行 `./run.sh`，打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)
2. **接口配置**：填写密钥 → **保存** → 各能力点 **测试**
3. **引擎设置**：组合三层（识别 / 句中 / 句末）→ 捕获音频

测试通过后接口才会出现在下拉框（`VERIFIED_*` 写入当前进程，重启后需重新测试）。

## 三层引擎

| 层 | 可选接口（节选） |
|---|---|
| 识别 | 本地 Whisper、腾讯云、OpenAI |
| 句中 | TMT、百度、七牛/阿里/DeepSeek/OpenAI LLM、Google、DeepL、Argos |
| 句末 | 同上 LLM / MT / Argos 等 |

## 项目结构

```
server/           FastAPI + WebSocket
  provider_registry.py   接口列表（单一来源）
  provider_enable.py     测试通过门控
  provider_test.py       连通性测试
  asr/partial/final_config.py  各层路由
static/           Web 控制台
extension/        Chrome 悬浮字幕扩展
```

## 环境变量

复制 `.env.example` → `.env`。常用：

- `ASR_PROVIDER` — 默认识别（须对应 `VERIFIED_ASR_*=1` 才出现在下拉）
- `TENCENT_ASR_*` / `TMT_*` — 腾讯云
- `QINIU_AI_*` / `ALIYUN_AI_*` / `DEEPSEEK_*` / `OPENAI_*` — LLM
- `BAIDU_*` / `DEEPL_*` — 机器翻译
- `VOICEBRIDGE_PORT` — 端口（默认 8765）

## Chrome 扩展

1. `chrome://extensions` → 开发者模式 → 加载 `extension/`
2. 先在 Web 控制台完成接口测试
3. 扩展弹窗选择引擎 → 开始字幕

## API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 状态与已验证接口列表 |
| POST | `/api/cloud/settings` | 保存密钥 |
| POST | `/api/cloud/test` | 测试并验证接口 |
| POST | `/api/engine/settings` | 保存引擎组合 |
| WS | `/ws` | PCM 音频流 |
