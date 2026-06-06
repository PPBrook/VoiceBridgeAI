# VoiceBridgeAI

Chrome 标签页英文音频 → 实时识别 → 中英双语字幕。Web 控制台 + Chrome 扩展。

## 快速开始

```bash
cp .env.example .env    # 可选；全本地可不填 Key
./run.sh
```

打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)（端口见 `VOICEBRIDGE_PORT`）。

## 页面

| 路径 | 用途 |
|---|---|
| `/` | 引擎设置 + 标签页音频捕获 |
| `/config` | 云端密钥：保存 → 写入 `.env` → 测试 |
| `/guide/provider-keys` | 各接口官网与密钥说明（HTML） |
| `/docs/` | Markdown 文档静态目录 |

## 推荐流程

1. **离线试用**：`/` 默认 `Whisper + Argos + Argos`，直接捕获。
2. **云端**：`/config` 填 Key → **保存** → **测试**（悬停状态看详情）。
3. **引擎**：`/` 选三层组合；句中推荐 MT，句末推荐 LLM（见 [ENGINE_PAIRING.md](docs/ENGINE_PAIRING.md)）。
4. **扩展**：见 [extension/README.md](extension/README.md)，可单独加载 `extension/` 目录。

## 三层引擎

| 层 | 默认可选 | 云端示例 |
|---|---|---|
| 识别 | 本地 Whisper | 腾讯云、OpenAI |
| 句中 | Argos 离线 | TMT、百度、LLM 快译… |
| 句末 | Argos / **不翻译** | LLM 润色、MT… |

- 离线默认可用项**无需**在 `/config` 测试。
- 云端接口：**测试通过**后才出现在下拉框；`VERIFIED_*` 在进程内生效，重启后靠启动自动测试或手动一键测试。
- OpenAI：**识别**测试只验 Key；**句中/句末**走 Chat，需账户有余额（429 = 配额不足）。

## 项目结构

```
server/
  main.py                 FastAPI + WebSocket
  provider_registry.py    接口 ID / 组合规则（后端单一来源）
  provider_enable.py      测试门控 + 离线默认可用
  provider_test.py        连通性测试
  cloud_config.py         密钥读写
  env_persist.py          合并写入 .env（密钥 + 引擎）
  engine_config.py        三层引擎统一状态
  asr/partial/final_config.py
  translate_*.py          各厂商适配
static/
  index.html, config.html
  js/app.js, config.js, engine-select.js, capture.js
extension/                Chrome 扩展（本仓库 extension/，见 extension/README.md）
docs/
  ENGINE_PAIRING.md
  PROVIDER_KEYS.md
```

## 环境变量（`.env`）

复制 `.env.example`。密钥字段与 `/config` 表单一一对应；**保存配置**会合并写入 `.env`。

引擎字段（控制台改引擎时也会写入）：

- `ASR_PROVIDER` / `PARTIAL_PROVIDER` / `FINAL_PROVIDER` / `REVISE_MODE`

常用密钥：`TENCENT_ASR_*`、`QINIU_AI_*`、`OPENAI_*` 等 — 详见 [密钥文档](http://127.0.0.1:8765/guide/provider-keys)。

其他：

- `VOICEBRIDGE_PORT` — 默认 `8765`（`run.sh` 与 `main.py` 均读取）
- `AUTO_TEST_ON_START=1` — 启动时自动测试已配置接口

## API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 健康检查、引擎选项、已验证接口 |
| GET | `/api/cloud/settings` | 云端配置状态 |
| POST | `/api/cloud/settings` | 保存密钥 → `.env` |
| POST | `/api/cloud/test` | 测试单项 |
| POST | `/api/cloud/test-all` | 一键测试 |
| POST | `/api/engine/settings` | 保存引擎 → 内存 + `.env` |
| WS | `/ws` | PCM 音频流 |

## Chrome 扩展

扩展位于本仓库 **`extension/`** 目录（与服务端同一仓库，符合比赛指定仓库要求）。

1. 仓库根目录启动 `./run.sh`
2. `chrome://extensions` → 加载 **`extension/`** 目录（详见 [extension/README.md](extension/README.md)）
3. 弹窗配置服务端地址与引擎 → **开始悬浮字幕**

默认引擎：`local + argos + argos`。扩展与服务端 API 见 [extension/API.md](extension/API.md)。
