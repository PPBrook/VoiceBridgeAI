# 作品提交说明（feat/macapp → main）

本文件归档本次 macOS 客户端作品的合并内容，便于评审老师查阅。功能代码已通过 `feat/macapp` 合并至 `main`（commit `35aeeae`）。

## 下载试用（推荐）

**无需 clone、无需配置环境。** 请见仓库根目录 [README](../README.md) 中 **「评审 / 老师试用」**：

1. 下载 [releases/VoiceBridgeAI-Local.zip](../releases/VoiceBridgeAI-Local.zip)（Git LFS，约 442 MB）
2. 解压 → **右键打开** `VoiceBridgeAI-Local.app`
3. 授予 **屏幕录制** 权限 → **开始悬浮字幕**

安装包已内置：**Whisper 离线识别**、**Argos 离线翻译**、演示用云端 API 配置；开箱可离线演示，亦可在设置中切换云端引擎。

## Summary

- **macOS 原生客户端**：ScreenCaptureKit 系统音频 → WebSocket → Python 引擎 → 悬浮字幕
- **观看场景**：演讲 / 技术分享 / 会议 / 网课 — 影响 VAD 断句与 LLM 润色；运行中热更新
- **字幕体验**：背景/文字透明度、静音清屏、观看场景标签、字幕记录与多种导出格式
- **引擎模块化**：`server/routes/`、`local_models` 拆分、`app_bootstrap` 启动流程
- **双安装包变体**：Cloud（纯云端）/ Local（内置本地模型）；评审 zip 为 Local 完整版
- **文档**：README、`docs/development.md`、`docs/architecture.md` 与源码目录 README 对齐

## 主要 Commits（合并前 feat/macapp 增量）

| Commit | 说明 |
|--------|------|
| `b8070db` | Cloud/Local App 变体、打包脚本、文档整理 |
| `aae0cc1` | 评审用 zip（Git LFS）与 README 试用说明 |
| `37415aa` | 打包密钥统一从仓库 `.env` 合并 |
| `ab3db0d` | 字幕记录、浮层增强、偏好合并 |
| `538e650` | server 路由与 macOS 大面板拆分 |
| `c4fc593` | 观看场景预设与引擎体验优化 |

（更早功能已通过 PR #26–#28 等陆续合并。）

## 仓库结构速览

```
VoiceBridgeAI/
  releases/VoiceBridgeAI-Local.zip   # 评审安装包（LFS）
  server/                            # FastAPI + WebSocket 引擎
  desktop/macos/                     # Swift App + build-app-*.sh
  docs/                              # 开发 / 架构 / 本说明
```

## 开发复现（可选）

```bash
cp .env.example .env   # 仓库已含演示 .env，clone 后可直接用
./run.sh
cd desktop/macos && ./run.sh
```

重新打包 Local 版：`cd desktop/macos && ./build-app-local.sh`

## Test plan

- [x] `./run.sh` 启动，`GET /api/health` 正常
- [x] 主窗口 / 设置页切换观看场景，运行中热更新
- [x] 悬浮字幕 partial / final 显示；暂停约 2.5s 清屏
- [x] 设置 → 字幕记录：定稿句写入文件
- [x] `VoiceBridgeAI-Local.app` 右键打开，离线 Whisper + Argos 可用
- [x] `swift build -c release` 通过

## 限制

- App **未签名**；首次打开需右键 → 打开
- 安装包体积约 **1 GB**（含 Python 运行时与本地模型）
- 仅 macOS 13+；采集系统音频，无 YouTube CC 模式
