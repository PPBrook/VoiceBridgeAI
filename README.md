# VoiceBridgeAI

AI 同声传译助手 — 实时将英文音频翻译为中文（字幕 / 语音），支持识别与翻译自动修正。

**议题：** 七牛云 × XEngineer 暑期实训营 · 题目二 · AI 同声传译助手

## 功能

- FastAPI 服务 + `/api/health`
- Chrome 标签页音频捕获
- WebSocket 实时传输 PCM
- 英文语音识别（Whisper base.en）→ 按句字幕（VAD 静音分句）
- 英文 → 中文机器翻译（双语字幕）

## 快速启动

```bash
chmod +x run.sh && ./run.sh
```

```bash
curl http://127.0.0.1:8765/api/health
```

浏览器（**Chrome**）：[http://127.0.0.1:8765](http://127.0.0.1:8765)

## 手动启动

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd server && python main.py
```

## 第三方依赖


| 依赖                                                          | 用途                  | 官网                                |
| ----------------------------------------------------------- | ------------------- | --------------------------------- |
| [FastAPI](https://fastapi.tiangolo.com/)                    | HTTP / WebSocket 服务 | fastapi.tiangolo.com              |
| [Uvicorn](https://www.uvicorn.org/)                         | ASGI 服务器            | uvicorn.org                       |
| [faster-whisper](https://github.com/SYSTRAN/faster-whisper) | 英文 ASR（Whisper 推理）  | github.com/SYSTRAN/faster-whisper |
| [NumPy](https://numpy.org/)                                 | PCM 重采样与数组处理        | numpy.org                         |
| [deep-translator](https://github.com/nidhaloff/deep-translator) | 英译中（Google Translate 非官方接口） | github.com/nidhaloff/deep-translator |


运行时模型：`Systran/faster-whisper-base.en`（首次启动自动下载）

浏览器 API（无额外安装）：`getDisplayMedia`、`WebSocket`、`MediaStreamTrackProcessor`

## 原创部分

以下为自主实现（非第三方库直接提供的能力）：

- 标签页音频捕获与 Chrome 适配（`static/js/capture.js`）
- PCM 采集与 WebSocket 传输（`static/js/app.js`、`server/main.py`）
- 音频缓冲、重采样与 ASR 调度（`server/asr.py`）
- RMS 静音检测与按句切分（`server/vad.py`）
- 英译中翻译（`server/translate.py`）
- 双语字幕展示（`static/`）

