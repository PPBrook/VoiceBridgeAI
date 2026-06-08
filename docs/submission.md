# 作品提交说明

面向评审：下载 `releases/*.zip` 解压后使用，无需配置 Python、无需下载模型。

## 项目背景

VoiceBridgeAI 面向**英文系统音频 → 实时中文悬浮字幕**场景（演讲、技术分享、会议、网课等）。客户端采集系统播放的声音，Python 侧车完成识别与翻译，结果以置顶悬浮窗显示；支持观看场景、字幕记录与 Local/Cloud 两种安装变体。

项目演进：**Web + 浏览器扩展** → **macOS 原生 App**（本提交）→ 并行探索 **Windows 客户端**。详见根目录 [README 分支说明](../README.md#项目演进与其它分支)（[`legacy/web-only`](https://github.com/PPBrook/VoiceBridgeAI/tree/legacy/web-only)、[`feat/winapp`](https://github.com/PPBrook/VoiceBridgeAI/tree/feat/winapp)）。

**Demo 视频**（带配音，覆盖主要功能）：[哔哩哔哩 →](https://www.bilibili.com/video/BV1C4Et6PESe/)

> Demo 仅 **macOS 端**（`main`）；Windows 版未纳入视频。

### Local 与 Cloud 怎么选？

| 版本 | 适合谁 | 说明 |
|------|--------|------|
| **Local**（**推荐评审试用**） | 希望开箱即用 | 内置 Whisper + Argos，**离线即可出字幕**；打包时含演示用云端配置，一般无需自备 Key |
| **Cloud** | 已有云端 API、想小体积安装 | zip 约 26 MB；须在 App **设置 → 云端** 填写 ASR/翻译密钥，无本地模型 Tab |

## ⚠️ 无法打开 /「已损坏，无法打开」

> **这通常不是 App 真损坏**，而是 macOS **Gatekeeper** 对下载文件附加的**隔离（quarantine）标记**。  
> 解压后执行（路径按实际位置修改）：

```bash
xattr -cr VoiceBridgeAI-Local.app
# 示例：xattr -cr ~/Downloads/VoiceBridgeAI-Cloud.app
# 示例：xattr -cr ~/Applications/VoiceBridgeAI-Local.app
```

然后 **右键 → 打开**（未签名 App，首次不能双击）。

## 快速试用（Local 推荐）

1. 获取 `releases/VoiceBridgeAI-Local.zip`（zip 约 **430 MB**，解压后 ~1.1 GB，Git LFS）
2. 解压（`ditto -xk`、unzip 或 Finder 均可）：

```bash
cd VoiceBridgeAI
git lfs pull --include="releases/VoiceBridgeAI-Local.zip"    # 若 zip 仅几 KB
ditto -xk releases/VoiceBridgeAI-Local.zip .
```

3. **清除隔离并打开**：

```bash
xattr -cr VoiceBridgeAI-Local.app
cp -R VoiceBridgeAI-Local.app ~/Applications/    # 可选
open ~/Applications/VoiceBridgeAI-Local.app        # 仍建议右键 → 打开
```

4. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
5. 播放含英文的系统音频 → **开始悬浮字幕**

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 配置。  
日志：`~/Library/Application Support/VoiceBridgeAI-Local/server.log`

**系统要求：** macOS 13+

### 云端版（可选）

体积更小，需自备云端 API Key（设置 → 云端）。`releases/VoiceBridgeAI-Cloud.zip`（zip 约 **26 MB**，解压后 ~70 MB）：

```bash
ditto -xk releases/VoiceBridgeAI-Cloud.zip .
xattr -cr VoiceBridgeAI-Cloud.app
open VoiceBridgeAI-Cloud.app
```

### 只下载 Local zip

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout init --no-cone
git sparse-checkout set /releases/VoiceBridgeAI-Local.zip
git checkout

ls -lh releases/VoiceBridgeAI-Local.zip   # 应约 430 MB
git lfs pull --include="releases/VoiceBridgeAI-Local.zip"

ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
```

> sparse 须 `--no-cone` 且路径写 `/releases/….zip`，否则会报 **is not a directory**。  
> 裸 `git lfs pull` 若报 `missing object`，改用 `--include=…`。

### 故障排查

| 现象 | 处理 |
|------|------|
| **「已损坏，无法打开」** | **先** `xattr -cr /path/to/VoiceBridgeAI-*.app`，再右键 → 打开 |
| zip 只有几 KB | `git lfs pull --include="releases/VoiceBridgeAI-Local.zip"` |
| sparse 报 is not a directory | `init --no-cone` + `set /releases/VoiceBridgeAI-Local.zip` |
| Local zip 远小于 ~400 MB | 文件不完整 → 重新 pull（完整约 430 MB） |
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
| 演进 | Web 扩展 → macOS App（主）；Windows 客户端见 `feat/winapp` |
| 限制 | App 未签名；Local zip ~430 MB（解压 ~1.1 GB）/ Cloud ~26 MB（解压 ~70 MB）；macOS 13+ |

架构与开发细节见 [architecture.md](architecture.md)、[development.md](development.md)。分支与 Demo 见 [../README.md](../README.md)。
