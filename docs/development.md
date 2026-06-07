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

改 **Python**（`server/`）后：终端 1 里 `Ctrl+C`，再 `./run.sh`。  
改 **Swift** 后：终端 2 里 `Ctrl+C`，再 `./run.sh`（会自动重新编译）。

## 仓库结构

```
VoiceBridgeAI/
  run.sh                 开发启动 Python 引擎
  requirements.txt       Python 依赖
  .env.example           引擎配置模板
  cloud-ui.json.example  云端卡片隐藏偏好模板
  server/                FastAPI 侧车（见 server/README.md）
    main.py              入口
    app_bootstrap.py     启动与 lifespan
    routes/              HTTP / WS 路由
    config/ core/ providers/
  desktop/macos/         Swift App 源码与打包脚本
  docs/                  架构与开发说明
  transcripts/           开发时字幕记录（gitignore）
```

主分支仅维护 **macOS App + Python 引擎**。旧 Web UI / 浏览器扩展在其它分支，根目录不含 `extension/`、`static/`。

## 数据放在哪

| 文件 / 目录 | 开发（`./run.sh`） | App 安装版 |
|-------------|-------------------|------------|
| `.env` | 仓库根 | `~/Library/Application Support/VoiceBridgeAI/` |
| `cloud-ui.json` | 仓库根 | 同上 |
| `models/` | 仓库根 | 同上 |
| `transcripts/` | 仓库根 | 同上（可自定义目录） |
| `server.log` | — | 同上 |

开发时 Swift 通过 `VOICEBRIDGE_ROOT` / `VOICEBRIDGE_DATA_DIR` 指向仓库根，与引擎一致。

## 本地模型（开发调试）

设置页 **本地模型** 对应 API：

| 操作 | API |
|------|-----|
| 开始下载 | `POST /api/models/local/download` → 立即返回 `job` |
| 查询进度 | `GET /api/models/local/download/{jobId}` |
| 启用/切换 | `POST /api/models/local/settings` |
| 删除 | `POST /api/models/local/delete` |

下载在后台线程执行，App 可关闭设置页；`GET /api/health` 的 `activeDownload` 可恢复进行中的任务。

## 主窗口、悬浮字幕与记录

| 位置 | 行为 |
|------|------|
| 主窗口 × | 退出 App |
| 主窗口 − | 收起到菜单栏 |
| 主窗口 · 观看场景 | 切换断句/润色预设；字幕运行中**即时生效** |
| 设置 → 引擎 · 观看场景 | 同上；保存后运行中也会通过 WebSocket 热更新 |
| 设置 → 引擎 · ASR/翻译 | 保存后若字幕在运行，**更换 ASR 或翻译接口**需停止再开始 |
| 悬浮字幕 · 记 | 开关字幕记录；与设置 → 字幕记录 同步 |
| 悬浮字幕 · 背景/文字 | 调节面板与字幕透明度 |
| 设置 → 字幕记录 | 保存目录、文件名模板、内容形式；可转换已有 md/txt |
| 菜单栏 · 打开字幕记录 | 在 Finder 中打开记录目录 |

暂停或切视频时，约 **2.5s** 静音会自动清空悬浮字幕（会话不中断）。

### 字幕记录内容形式

| 形式 | 说明 |
|------|------|
| 中英对照（分区） | 每句分「英文」「中文」块 |
| 中英结合（连续） | 每句英文+中文连续排列 |
| 纯英文 / 纯中文 | 只保留一种语言 |

转换已有文件时，在同目录生成带后缀的新文件（如 `_en`、`_zh`、`_mix`），原文件保留。

## 观看场景

| 模式 | 典型内容 | 断句 | 润色侧重 |
|------|----------|------|----------|
| 演讲 | TED、发布会 | 停顿 ~1s | 口语有节奏 |
| 技术分享 | Meetup、架构讲解 | 概念块完整 | 术语一致 |
| 会议 | 峰会 Q&A | 短停顿快切 | 短句直译 |
| 网课 | MOOC、培训 | 长停顿整段 | 知识点连贯 |

逻辑：`server/core/vad.py`（断句）、`server/config/revise_config.py`（预设）、`server/core/llm_compat.py`（润色提示）。

## 故障排查

**端口占用** — 在跑引擎的终端 `Ctrl+C`，或：

```bash
kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)
./run.sh
```

**改代码后行为不对** — 确认已重启对应终端里的进程。

**本地模型状态不对** — 下载/删除/切换后 App 会刷新；仍异常则重启引擎。

**Argos 删除后仍显示已安装** — 确认引擎已重启（旧进程可能缓存 Argos 语言列表）。
