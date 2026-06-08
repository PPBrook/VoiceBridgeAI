# 作品提交说明

面向评审：下载 `releases/*.zip`，**必须在终端解压**后使用，无需配置 Python、无需下载模型。

**Demo 视频**（带配音，覆盖主要功能）：[哔哩哔哩 →](https://www.bilibili.com/video/BV1C4Et6PESe/)

> Demo 仅涉及 **macOS 端**；Windows 版（`feat/winapp`）因时间有限未完成测试与录制，视频未展示 Windows 端。

## ⚠️ 解压必读：勿双击 zip

> **用 Finder 或「归档实用工具」双击解压，大概率会得到损坏的 `.app`**（系统提示「已损坏，无法打开」，或 App 无法启动）。  
> **这不是签名问题，是解压方式错误。** 请严格按下方终端命令操作。

## 快速试用（Local 推荐）

1. 获取 `releases/VoiceBridgeAI-Local.zip`（约 **1.2 GB**，Git LFS）
2. **终端解压（必须）**：

```bash
cd VoiceBridgeAI
git lfs pull    # 必须：clone 后若 zip 只有几 KB，说明 LFS 未拉取

# 必须：ditto 解压（勿双击 zip）
ditto -xk releases/VoiceBridgeAI-Local.zip .

# 备选（不如 ditto 可靠）
# unzip -q releases/VoiceBridgeAI-Local.zip
```

3. 清除隔离属性并打开：

```bash
xattr -cr VoiceBridgeAI-Local.app
cp -R VoiceBridgeAI-Local.app ~/Applications/
open ~/Applications/VoiceBridgeAI-Local.app
```

4. **右键** App → **打开**（未签名，首次不能双击）
5. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
6. 播放含英文的系统音频 → **开始悬浮字幕**

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 配置。  
日志：`~/Library/Application Support/VoiceBridgeAI-Local/server.log`

**系统要求：** macOS 13+

### 云端版（可选）

`releases/VoiceBridgeAI-Cloud.zip`（约 **70 MB**），**同样必须在终端解压**：

```bash
git lfs pull
ditto -xk releases/VoiceBridgeAI-Cloud.zip .
xattr -cr VoiceBridgeAI-Cloud.app
open VoiceBridgeAI-Cloud.app
```

### 只下载 zip

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.zip
git checkout
git lfs pull
ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
```

### 故障排查

| 现象 | 处理 |
|------|------|
| zip 只有几 KB | **必须**运行 `git lfs pull` |
| Local zip 远小于 1 GB | 文件不完整（打包中断）→ 重新 `git pull` / `git lfs pull` |
| 「已损坏，无法打开」 | 多半 Finder 双击解压 → **删除 .app**，用 `ditto -xk …` 重解 |
| 无法打开 App | `xattr -cr VoiceBridgeAI-Local.app`，再 **右键 → 打开** |
| 无字幕 | 确认 **屏幕录制** 权限；确认系统在播放英文音频 |
| 其它 | `~/Library/Application Support/VoiceBridgeAI-Local/server.log` |

---

## 作品简介

| 项目 | 说明 |
|------|------|
| 形态 | macOS 菜单栏 App + 悬浮字幕 |
| 数据流 | 系统音频 → ASR → 翻译/润色 → 悬浮显示 |
| 观看场景 | 演讲 / 技术 / 会议 / 网课 |
| 其它 | 字幕记录导出、透明度调节、静音自动清屏 |
| 限制 | App 未签名；Local zip ~1.2 GB / Cloud ~70 MB；仅 macOS |

架构与开发细节见 [architecture.md](architecture.md)、[development.md](development.md)。
