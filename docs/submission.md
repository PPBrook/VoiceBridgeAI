# 作品提交说明

面向评审：clone 或 sparse-checkout 后**直接使用 `.app`**，无需配置 Python、无需下载模型、**无需解压 zip**。

**Demo 视频**（带配音，覆盖主要功能）：[哔哩哔哩 →](https://www.bilibili.com/video/BV1C4Et6PESe/)

> Demo 仅涉及 **macOS 端**；Windows 版（`feat/winapp`）因时间有限未完成测试与录制，视频未展示 Windows 端。

## 快速试用（Local 推荐）

1. 获取 `releases/VoiceBridgeAI-Local.app`（约 1.2 GB）
2. 安装并打开：

```bash
cp -R releases/VoiceBridgeAI-Local.app ~/Applications/
xattr -cr ~/Applications/VoiceBridgeAI-Local.app
open ~/Applications/VoiceBridgeAI-Local.app
```

3. **右键** App → **打开**（未签名，首次不能双击）
4. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
5. 播放含英文的系统音频 → **开始悬浮字幕**

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 配置。  
日志：`~/Library/Application Support/VoiceBridgeAI-Local/server.log`

**系统要求：** macOS 13+

### 云端版（可选）

`releases/VoiceBridgeAI-Cloud.app`（约 77 MB），依赖云端 ASR/翻译。配置目录：`~/Library/Application Support/VoiceBridgeAI-Cloud/`。

### 只下载某一个 App

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.app   # 或 Cloud
git checkout
```

### 故障排查

| 现象 | 处理 |
|------|------|
| 无法打开 | `xattr -cr /path/to/VoiceBridgeAI-Local.app`，再 **右键 → 打开** |
| 无字幕 | 确认 **屏幕录制** 权限；确认系统在播放英文音频（非麦克风） |
| 其它 | 查看 `~/Library/Application Support/VoiceBridgeAI-Local/server.log` |

---

## 作品简介

| 项目 | 说明 |
|------|------|
| 形态 | macOS 菜单栏 App + 悬浮字幕 |
| 数据流 | 系统音频 → ASR → 翻译/润色 → 悬浮显示 |
| 观看场景 | 演讲 / 技术 / 会议 / 网课 |
| 其它 | 字幕记录导出、透明度调节、静音自动清屏 |
| 限制 | App 未签名；Local ~1.2 GB / Cloud ~77 MB；仅 macOS |

架构与开发细节见 [architecture.md](architecture.md)、[development.md](development.md)。
