# macOS App

Swift 原生 UI：菜单栏、设置、ScreenCaptureKit 采音、WebSocket 连 Python 引擎、悬浮字幕。

## 目录

```
desktop/macos/
  Package.swift
  run.sh / build-app-{local,cloud}.sh
  scripts/              run-server.sh、bundle-seed、prepare-bundled-models.py
  Sources/VoiceBridgeAI/
    App/                入口、菜单栏、BundleVariant
    Settings/           引擎、本地模型、字幕记录
    Cloud/              接口密钥
    Capture/            屏幕录制、系统音频
    Session/            WebSocket、字幕、记录
    Overlay/            主窗口、悬浮字幕
    Sidecar/            Python 侧车启动与路径
```

## 开发

```bash
# 终端 1 — 仓库根
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

详见 [docs/development.md](../docs/development.md)。

## 构建与发布

```bash
./run.sh                          # 确保 .venv 已创建
cd desktop/macos
./build-app-local.sh              # → dist/VoiceBridgeAI-Local.app
./build-app-cloud.sh              # → dist/VoiceBridgeAI-Cloud.app
./scripts/publish-release.sh local   # 复制到 releases/（不压缩）
```

| 变体 | 产物 | 说明 |
|------|------|------|
| cloud | `VoiceBridgeAI-Cloud.app` | 无本地模型 Tab，依赖云端 API |
| local | `VoiceBridgeAI-Local.app` | 内置 Whisper + Argos |

产物在 `dist/`（gitignore）。架构见 [docs/architecture.md](../docs/architecture.md)。
