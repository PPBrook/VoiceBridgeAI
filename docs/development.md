# 开发指南

## 日常流程（两个终端）

```bash
# 终端 1 — 引擎
cd VoiceBridgeAI
cp .env.example .env    # 首次
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
  .env.example           配置模板（复制为 .env）
  server/                FastAPI 侧车（见 server/README.md）
  desktop/
    macos/               Swift App 源码与打包脚本
  docs/                  架构与开发说明
```

主分支仅维护 **macOS App + Python 引擎**。旧 Web UI / 浏览器扩展在其它分支，根目录不含 `extension/`、`static/`。

## 数据放在哪

| 文件 / 目录 | 开发（`./run.sh`） | App 安装版 |
|-------------|-------------------|------------|
| `.env` | 仓库根 | `~/Library/Application Support/VoiceBridgeAI/` |
| `cloud-ui.json` | 仓库根 | 同上 |
| `models/` | 仓库根 | 同上 |
| `server.log` | — | 同上 |

开发时 Swift 通过 `VOICEBRIDGE_ROOT` / `VOICEBRIDGE_DATA_DIR` 指向仓库根，与引擎一致。

## 本地模型（开发调试）

设置页 **本地模型** 对应 API：

| 操作 | API |
|------|-----|
| 下载 | `POST /api/models/local/download` `{ id, whisperModel? }` |
| 启用/切换 | `POST /api/models/local/settings` |
| 删除 | `POST /api/models/local/delete` `{ id, whisperModel? }` |

Whisper 支持多规格（`tiny.en` / `base.en`）分别下载与删除。Argos 以 marker + 语言包目录判断是否已安装。

## 主窗口操作

| 按钮 | 行为 |
|------|------|
| 红色 × | 退出 App |
| 黄色 − | 收起到菜单栏（后台继续运行） |

## 故障排查

**端口占用** — 在跑引擎的终端 `Ctrl+C`，或：

```bash
kill $(lsof -t -iTCP:8765 -sTCP:LISTEN)
./run.sh
```

**改代码后行为不对** — 确认已重启对应终端里的进程。

**本地模型状态不对** — 下载/删除/切换后 App 会刷新；仍异常则重启引擎。

**Argos 删除后仍显示已安装** — 确认引擎已重启（旧进程可能缓存 Argos 语言列表）。
