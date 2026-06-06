# VoiceBridgeAI

**议题：** 七牛云 × XEngineer 暑期实训营 · 题目二

Chrome 标签页英文音频 → 实时识别 → 中英双语字幕。提供 Web 控制台与 Chrome 悬浮字幕扩展两种使用方式。

## 简介

用户在浏览器中播放英文视频时，本系统捕获当前标签页音频，经 WebSocket 推送到本地 FastAPI 服务，完成「识别 → 句中翻译 → 句末润色 → 字幕修正」流水线，并将双语字幕实时展示在页面列表或视频悬浮层上。

三层引擎（识别 / 句中 / 句末）各自独立可选，可按演示场景切换预设，也可自由组合接口。

## 快速开始

```bash
chmod +x run.sh && ./run.sh
```

1. 打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)（Chrome / Edge）
2. **API 配置** 填写密钥（全本地可跳过）
3. **引擎设置** 选三层接口或快速预设 → **捕获音频**

无 Key 演示：选预设 **路径 B**（Whisper + Argos）。持久配置：`cp .env.example .env`

**Chrome 扩展：** 先启动服务 → `chrome://extensions` 开启开发者模式 → 加载 `extension/` → 在视频页点击扩展「开始悬浮字幕」

## 三层引擎

| 层 | 配置 | 可选接口 |
|----|------|----------|
| 语音识别 | `ASR_PROVIDER` | 腾讯云流式 · 本地 Whisper |
| 句中翻译 | `PARTIAL_PROVIDER` | 腾讯 TMT · Google · Argos 离线 · 阿里云 LLM |
| 句末润色 | `FINAL_PROVIDER` | 七牛 AI · 阿里云 · TMT · Google · Argos · 不润色 |

`.env` 示例：

```env
ASR_PROVIDER=tencent
PARTIAL_PROVIDER=tmt
FINAL_PROVIDER=qiniu
REVISE_MODE=balanced
```

也可在控制台或扩展 popup 中切换，运行时写入环境变量（当前进程有效）。

## 演示预设

| 预设 | 识别 | 句中 | 句末 | 所需 Key |
|------|------|------|------|----------|
| A 云端双擎 | 腾讯云 | TMT | 七牛 | 腾讯云 + 七牛 |
| B 全本地 | Whisper | Argos | Argos | 无 |
| C 联网兜底 | Whisper | Google | Google | 无（需联网） |

未配置腾讯云时，预设 A 的识别会自动降级为本地 Whisper，其余层仍按预设运行。

## 实现思路

```
标签页音频 (tabCapture)
    │  PCM 16k
    ▼
WebSocket ──► FastAPI main.py
    │
    ├─ ASR
    │   ├─ tencent：流式 WebSocket，低延迟 partial/final
    │   └─ local：VAD 切句 + faster-whisper
    │
    ├─ 句中翻译 (partial_config)
    │   └─ 识别文本变化时即时出中文草稿
    │
    ├─ 句末润色 (final_config)
    │   └─ 一句结束时用 LLM/TMT 润色定稿
    │
    └─ Revise (revise.py)
        └─ debounce 合并 partial，减少闪烁；可选回溯修正

    ▼
Web 控制台列表 / 扩展 content script 悬浮层
```

**设计要点：**

- **三层解耦**：`asr_config` / `partial_config` / `final_config` 各自路由，`engine_config` 统一预设与状态。
- **双引擎翻译**：句中快、句末准；句末可沿用句中结果（`none`）或换更强模型。
- **扩展与控制台共用后端**：扩展通过 offscreen + background 采集音频，配置项与服务端 API 对齐。

## 项目结构

```
VoiceBridgeAI/
├── run.sh                      # 启动脚本
├── .env.example                # 环境变量模板
├── server/
│   ├── main.py                 # FastAPI · WebSocket 入口
│   ├── engine_config.py        # 三层引擎统一配置与预设
│   ├── asr_config.py           # 识别路由
│   ├── partial_config.py       # 句中翻译路由
│   ├── final_config.py         # 句末润色路由
│   ├── translate.py            # 翻译调度（缓存 + 降级）
│   ├── translate_tmt.py        # 腾讯 TMT
│   ├── translate_qiniu.py      # 七牛 AI
│   ├── translate_aliyun.py     # 阿里云 DashScope
│   ├── translate_argos.py      # Argos 离线
│   ├── tencent_asr.py          # 腾讯云流式 ASR
│   ├── whisper_asr.py          # 本地 Whisper
│   ├── vad.py                  # 本地 VAD 切句
│   ├── revise.py               # 字幕 revise 调度
│   └── cloud_config.py         # API Key 管理
├── static/                     # Web 控制台
│   ├── index.html
│   └── js/app.js
└── extension/                  # Chrome MV3 悬浮字幕
    ├── manifest.json
    ├── background.js           # tabCapture · 消息路由
    ├── offscreen.js            # 音频采集 · WebSocket
    └── content/subtitle-overlay.js
```

## 技术栈

FastAPI · WebSocket · faster-whisper · 腾讯云 ASR/TMT · 七牛 AI · 阿里云 DashScope · Argos · Chrome Extension MV3
