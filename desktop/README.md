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
./scripts/publish-release.sh local   # → releases/*.zip
./scripts/publish-release.sh cloud
```

| 变体 | zip（解压后） | 说明 |
|------|---------------|------|
| cloud | `VoiceBridgeAI-Cloud.zip`（~26 MB / ~70 MB） | 无本地模型 Tab，依赖云端 API |
| local | `VoiceBridgeAI-Local.zip`（~430 MB / ~1.1 GB） | 内置 Whisper + Argos |

产物在 `dist/`（gitignore）。`releases/*.zip` 经 Git LFS 提交。评审侧：**解压 zip → `xattr -cr` .app → 右键打开**（解压方式不限；`xattr` 清除 Gatekeeper 隔离，见根目录 [README](../README.md)）。
