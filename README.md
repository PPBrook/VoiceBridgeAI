# VoiceBridgeAI

**议题：** 七牛云 × XEngineer 暑期实训营 · 题目二

## 项目简介

VoiceBridgeAI 是一个面向浏览器场景的 **AI 同声传译助手**：捕获 Chrome 标签页中的英文音频，实时识别并翻译为中文，以双语字幕形式呈现。适用于观看 YouTube 等英文视频时的「听译」需求。

除控制台页外，还提供 **Chrome 悬浮字幕扩展**，可在视频页直接叠加半透明字幕，无需切换标签页。

## 实现思路

```
浏览器采集音频（getDisplayMedia / tabCapture）
        ↓ PCM 流（WebSocket）
本地 FastAPI 服务
        ↓
┌───────────────────┬────────────────────┐
│ 云端路径           │ 本地路径            │
│ 腾讯云流式 ASR     │ VAD 分句 + Whisper │
└─────────┬─────────┴─────────┬──────────┘
          ↓                   ↓
     双擎翻译              Argos / Google
   TMT（句中）+            离线 / 在线
   七牛 LLM（句末）
          ↓
   Revise 调度（句内修正、debounce 翻译、可选回溯）
          ↓
     双语字幕推送 → 页面列表 / 扩展浮层
```

**要点：**

- **双后端 ASR**：云端走腾讯云 WebSocket 流式识别（低延迟演示）；本地走 VAD + faster-whisper，无需 API Key 即可完整演示。
- **双擎翻译**：句中用腾讯 TMT 快速出草稿，句末用七牛 LLM 润色；本地模式用 Argos 离线翻译。
- **Revise 机制**：同一句 partial 更新时字幕原地刷新，避免闪烁；支持实时优先 / 标准 / 精准三档纠正策略。
- **前后端分离**：浏览器只负责采音与展示，识别翻译逻辑集中在 Python 服务端，控制台与扩展共用同一 WebSocket 接口。

## 使用

```bash
chmod +x run.sh && ./run.sh
```

打开 [http://127.0.0.1:8765](http://127.0.0.1:8765)（Chrome / Edge）→ 配置 API → 选择引擎 → **捕获音频**。

无 Key 可选全本地路径（见下表）。持久配置可复制 `.env.example` 为 `.env`。

**悬浮字幕扩展：** 先启动服务，再在 `chrome://extensions` 开发者模式下加载 `extension/` 目录。

## 演示路径

| | 识别 | 翻译 | 需要 Key |
|---|------|------|----------|
| A 云端（推荐） | 腾讯云流式 ASR | TMT + 七牛 LLM | 腾讯云 + 七牛 |
| B 全本地 | Whisper | Argos 离线 | 否 |
| C 兜底 | Whisper | Google 在线 | 否（需联网） |

## 技术栈

FastAPI · WebSocket · faster-whisper · 腾讯云 ASR/TMT · 七牛 AI · Argos · Chrome Extension MV3（tabCapture / offscreen）
