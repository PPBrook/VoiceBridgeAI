# macOS App

Swift 原生 UI：菜单栏、设置窗口、ScreenCaptureKit 采音、WebSocket 连 Python 引擎、悬浮字幕。

## 目录

```
desktop/macos/
  Package.swift
  run.sh                     开发：编译并运行
  build-app.sh               构建脚本（参数 cloud | local）
  build-app-cloud.sh         → cloud 变体
  build-app-local.sh         → local 变体
  scripts/
    run-server.sh            App 内置侧车启动
    bundle-seed/             各变体默认 .env 种子
    prepare-bundled-models.py
  Sources/VoiceBridgeAI/
    App/                     入口、菜单栏、BundleVariant
    Settings/                引擎 / 本地模型 / 字幕记录
    Cloud/                   接口密钥（extension 拆分）
    Capture/                 屏幕录制、系统音频
    Session/                 WebSocket、字幕、记录
    Overlay/                 主窗口、悬浮字幕
    Sidecar/                 Python 侧车、路径
```

## 开发

```bash
# 终端 1 — 仓库根目录
./run.sh

# 终端 2
cd desktop/macos && ./run.sh
```

详见 [docs/development.md](../../docs/development.md)。

## App 变体

| 变体 | 产物 | 说明 |
|------|------|------|
| 开发 | `./run.sh` | 连仓库根目录引擎，全功能 |
| cloud | `VoiceBridgeAI-Cloud.app` | 无本地模型 Tab，依赖云端 API |
| local | `VoiceBridgeAI-Local.app` | 可内置 Whisper + Argos |

构建脚本在 `build-app*.sh`；产物在 `dist/`（gitignore）。

模块表见历史文档或 `Sources/VoiceBridgeAI/` 目录。
