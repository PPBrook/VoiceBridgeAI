# 开发指南

## 日常流程（两个终端）

```bash
# 终端 1 — 引擎
cd VoiceBridgeAI
cp .env.example .env              # 首次
cp cloud-ui.json.example cloud-ui.json   # 可选
./run.sh

# 终端 2 — Swift UI
cd VoiceBridgeAI/desktop/macos
./run.sh
```

改 **Python**（`server/`）后：终端 1 `Ctrl+C` → `./run.sh`。  
改 **Swift** 后：终端 2 `Ctrl+C` → `./run.sh`（自动重新编译）。

## 仓库结构

```
VoiceBridgeAI/
  run.sh
  requirements.txt
  requirements-cloud.txt
  .env.example
  cloud-ui.json.example
  server/
    main.py
    app_bootstrap.py
    routes/
    config/ core/ providers/
  desktop/macos/
  docs/
  models/          开发时本地模型（gitignore）
  transcripts/     开发时字幕记录（gitignore）
```

主分支维护 **macOS App + Python 引擎**。旧 Web / 浏览器扩展见其它分支。

## 项目概览

三层引擎：**ASR**（Whisper / 腾讯 / OpenAI）→ **句中翻译** → **句末润色**。

| 功能 | 说明 |
|------|------|
| 观看场景 | 演讲 / 技术 / 会议 / 网课 — VAD 断句与 LLM 润色；运行中可热更新 |
| 悬浮字幕 | 背景/文字透明度、英文显示、场景标签；静音 ~2.5s 自动清屏 |
| 字幕记录 | 定稿句写入文件，多种中英排版 |
| 本地模型 | Whisper + Argos，设置页下载与管理 |

### API（节选）

| 路径 | 说明 |
|------|------|
| GET `/api/health` | 状态、引擎、本地模型 |
| POST `/api/models/local/download` | 下载 Whisper / Argos |
| POST `/api/engine/settings` | 保存引擎与观看场景 |
| POST `/api/cloud/settings` | 保存云端密钥 |
| WS `/ws` | config + PCM → 字幕事件 |

完整列表：[server/README.md](../server/README.md)

## 数据目录

| 内容 | 开发（`./run.sh`） | 独立 App |
|------|-------------------|----------|
| `.env` | 仓库根 | Application Support（见下） |
| `cloud-ui.json` | 仓库根 | 同上 |
| `models/` | 仓库根 | 同上或 App 内 `bundled-models/` |
| `transcripts/` | 仓库根 | 同上（可自定义） |
| `server.log` | — | 同上 |

Swift 开发模式通过 `VOICEBRIDGE_ROOT` / `RepoRoot` 定位仓库根；引擎通过 `VOICEBRIDGE_DATA_DIR` 读写配置。

Application Support 目录名：

| 场景 | 路径 |
|------|------|
| 开发 / 标准 App | `~/Library/Application Support/VoiceBridgeAI/` |
| Cloud 变体 | `~/Library/Application Support/VoiceBridgeAI-Cloud/` |
| Local 变体 | `~/Library/Application Support/VoiceBridgeAI-Local/` |

## 本地模型

Whisper 权重在 `models/hf/hub/`；安装标记在 `models/whisper/.installed-{规格}`。  
Argos 标记在 `models/argos/.installed-en-zh`；语言包默认在 `~/.local/share/argos-translate/packages/`（开发下载后）。

设置页 **本地模型** API：

| 操作 | 路径 |
|------|------|
| 开始下载 | `POST /api/models/local/download` |
| 查询进度 | `GET /api/models/local/download/{jobId}` |
| 启用/切换 | `POST /api/models/local/settings` |
| 删除 | `POST /api/models/local/delete` |

## 界面行为

| 位置 | 行为 |
|------|------|
| 主窗口 × | 退出 App |
| 主窗口 − | 收起到菜单栏 |
| 观看场景 | 主窗口或设置 → 引擎；运行中热更新 |
| ASR/翻译接口 | 更换 provider 需停止再开始 |
| 悬浮 · 记 | 字幕记录开关（同步设置 → 字幕记录） |
| 悬浮 · 背景/文字 | 面板与字幕透明度 |
| 设置 → 字幕记录 | 目录、模板、内容形式、格式转换 |
| 菜单栏 · 打开字幕记录 | Finder 打开记录目录 |

暂停或切视频约 **2.5s** 静音会清空悬浮字幕（会话不中断）。

### 字幕记录形式

| 形式 | 说明 |
|------|------|
| 中英对照（分区） | 每句分英文/中文块 |
| 中英结合（连续） | 每句英文+中文连续 |
| 纯英文 / 纯中文 | 单语 |

## 观看场景

| 模式 | 典型 | 断句 | 润色 |
|------|------|------|------|
| 演讲 | TED、发布会 | ~1s | 口语节奏 |
| 技术分享 | Meetup | 概念块 | 术语稳定 |
| 会议 | Q&A | 短停顿 | 短句直译 |
| 网课 | MOOC | 长停顿 | 知识点整段 |

实现：`server/core/vad.py`、`server/config/revise_config.py`、`server/core/llm_compat.py`。

## 故障排查

**端口占用**

```bash
kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)
./run.sh
```

**改代码后行为不对** — 重启对应终端进程。

**本地模型状态异常** — 重启引擎；Argos 删除后需重启以刷新语言列表。

**Whisper 标记与权重分离** — 标记在 `models/whisper/`，HF 缓存可能在 `models/hf/hub/` 或 `~/.cache/huggingface/`；App Support 下若缺标记但 hub 有数据，可 `touch models/whisper/.installed-tiny.en`。
