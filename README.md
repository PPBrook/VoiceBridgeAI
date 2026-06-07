# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。Swift UI + Python 引擎侧车。

浏览器版备份分支：`legacy/web-only`

## 评审 / 老师试用（推荐）

无需安装 Python、无需配置密钥、无需下载模型。请使用已打包的 **本地完整版**（约 442 MB）：

1. 打开本仓库 **[releases/VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip)** 下载（Git LFS；若浏览器无法下载，请 clone 仓库后在该路径取文件，或在本机执行 `git lfs pull`）
2. 解压得到 `VoiceBridgeAI-Local.app`
3. **右键** App → **打开**（首次需确认；本 App 未签名）
4. 系统设置 → **隐私与安全性** → **屏幕录制** → 勾选 VoiceBridgeAI
5. 打开 App → **开始悬浮字幕**（播放含英文的系统音频，如浏览器视频）

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 密钥（可在设置中切换引擎）。  
配置与日志：`~/Library/Application Support/VoiceBridgeAI-Local/`

若提示「无法打开」：终端执行 `xattr -cr /path/to/VoiceBridgeAI-Local.app` 后再次右键打开。

**系统要求：** macOS 13+，Apple Silicon 或 Intel（与打包机同架构体验最佳）。

---

## 开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

详细说明：[docs/development.md](docs/development.md)

## 结构

```
VoiceBridgeAI/
  releases/              评审用安装包（VoiceBridgeAI-Local.zip，Git LFS）
  run.sh                 开发启动引擎
  requirements.txt       Python 依赖（完整）
  requirements-cloud.txt 云端版 App 用（无本地模型库）
  server/                FastAPI 引擎 → server/README.md
  desktop/macos/         Swift App → desktop/README.md
  docs/                  架构与开发 → docs/README.md
```

## 架构

```
ScreenCaptureKit → Swift App → ws://127.0.0.1:8765/ws → server/ → 悬浮字幕
```

三层引擎：**ASR**（Whisper / 腾讯 / OpenAI）→ **句中翻译** → **句末润色**。

| 功能 | 说明 |
|------|------|
| 观看场景 | 演讲 / 技术 / 会议 / 网课 — 影响 VAD 断句与 LLM 润色；运行中可热更新 |
| 悬浮字幕 | 背景/文字透明度、英文显示、场景标签；静音 ~2.5s 自动清屏 |
| 字幕记录 | 定稿句写入文件，多种中英排版，可转换已有 md/txt |
| 本地模型 | Whisper + Argos，设置页下载与管理 |

开发时数据目录为**仓库根**（`.env`、`models/`、`transcripts/`）。  
独立 App 安装版数据在 `~/Library/Application Support/VoiceBridgeAI*`（见 [docs/architecture.md](docs/architecture.md)）。

## API（节选）

| 路径 | 说明 |
|------|------|
| GET `/api/health` | 状态、引擎、本地模型 |
| POST `/api/models/local/download` | 下载 Whisper / Argos |
| POST `/api/engine/settings` | 保存引擎与观看场景 |
| POST `/api/cloud/settings` | 保存云端密钥 |
| WS `/ws` | config + PCM → 字幕事件 |

完整列表：[server/README.md](server/README.md)

## 故障排查

| 现象 | 处理 |
|------|------|
| 引擎启动失败 | 开发：终端 1 报错；App：`~/Library/Application Support/VoiceBridgeAI*/server.log` |
| 无 Whisper/Argos | 设置 → 本地模型（Local 安装包已内置） |
| 无声音 | 系统设置 → 屏幕录制权限 |
| 端口占用 | `kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)` 后重启 `./run.sh` |

## 限制

开发/App 均未签名；独立 App 体积较大（含 Python 运行时与本地模型）；仅本机；无 YouTube CC。
