# 作品提交说明

面向评审老师：下载安装包即可试用，**无需 clone 源码、无需配置 Python、无需下载模型**。

## 快速试用

1. 下载 [releases/VoiceBridgeAI-Local.zip](../releases/VoiceBridgeAI-Local.zip)（Git LFS，约 428 MB）
   - 浏览器：打开上述链接 → **Download**
   - 若 clone 仓库：执行 `git lfs pull`，文件在 `releases/` 目录
2. 解压得到 `VoiceBridgeAI-Local.app`
3. **右键** App → **打开**（本 App 未签名，首次不能双击）
4. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
5. 打开 App → **开始悬浮字幕**（播放含英文的系统音频，如浏览器视频）

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 配置（可在设置中切换引擎）。  
配置与日志：`~/Library/Application Support/VoiceBridgeAI-Local/`

**系统要求：** macOS 13+

### 云端版（可选）

体积约 77 MB，**不含** Whisper/Argos，默认使用云端 ASR/翻译（安装包内已合并演示用 API 配置）。**不压缩**，仓库内直接提供 `.app`，无需解压 zip。

**方式 A — 已有仓库 clone（最简单）**

```bash
cd VoiceBridgeAI
git pull
cp -R releases/VoiceBridgeAI-Cloud.app ~/Desktop/
xattr -cr ~/Desktop/VoiceBridgeAI-Cloud.app
open ~/Desktop/VoiceBridgeAI-Cloud.app
```

**方式 B — 只拉 Cloud App（sparse checkout）**

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Cloud.app
git checkout
open releases/VoiceBridgeAI-Cloud.app
```

**方式 C — svn export（无需 git lfs）**

```bash
svn export https://github.com/PPBrook/VoiceBridgeAI/trunk/releases/VoiceBridgeAI-Cloud.app ~/Desktop/VoiceBridgeAI-Cloud.app
xattr -cr ~/Desktop/VoiceBridgeAI-Cloud.app
open ~/Desktop/VoiceBridgeAI-Cloud.app
```

然后：**右键打开** App → 授予 **屏幕录制** → **开始悬浮字幕**。

配置目录：`~/Library/Application Support/VoiceBridgeAI-Cloud/`

### 无法解压 Local zip（提示已损坏）

| 实际大小 | 可能原因 |
|----------|----------|
| ~133 B，内容为 `version https://git-lfs.github.com/...` | 误把 **Local** zip 当普通文件 clone（Local 需 `git lfs pull`） |
| ~300 KB，用文本打开是 HTML | 用了错误链接；Local 请在 GitHub 文件页点 **下载图标** |
| 体积明显偏小（如几 MB） | 下载不完整，请重新下载 |

终端校验示例：

```bash
file ~/Downloads/VoiceBridgeAI-Local.zip
ls -lh ~/Downloads/VoiceBridgeAI-Local.zip
```

终端解压：`ditto -xk ~/Downloads/VoiceBridgeAI-Local.zip ~/Desktop/`

### 无法打开 App

终端执行（把路径换成实际位置）：

```bash
xattr -cr /path/to/VoiceBridgeAI-Local.app
```

然后再次 **右键 → 打开**。

### 无字幕 / 无声音

- 确认已授予 **屏幕录制** 权限
- 确认系统正在播放英文音频（App 采集的是系统声音，不是麦克风）
- 查看日志：`~/Library/Application Support/VoiceBridgeAI-Local/server.log`

---

## 作品简介

| 项目 | 说明 |
|------|------|
| 形态 | macOS 菜单栏 App + 悬浮字幕 |
| 数据流 | 系统音频 → Whisper 识别 → Argos 翻译 → 悬浮显示 |
| 观看场景 | 演讲 / 技术 / 会议 / 网课 — 影响断句与润色风格 |
| 其它功能 | 字幕记录导出、背景/文字透明度、静音自动清屏 |

```
ScreenCaptureKit → Swift App → Python 引擎 → 悬浮字幕
```

---

## 仓库结构（选读）

```
VoiceBridgeAI/
  releases/VoiceBridgeAI-Local.zip   # 评审推荐：离线完整版
  releases/VoiceBridgeAI-Cloud.app/    # 云端版（不压缩，直接使用）
  releases/VoiceBridgeAI-Local.zip     # 离线完整版（Git LFS）
  server/                            # Python 引擎
  desktop/macos/                     # Swift 客户端
  docs/                              # 开发与架构文档
```

需要自行编译或答辩源码结构时，见 [development.md](development.md)、[architecture.md](architecture.md)。

## 开发复现（选读）

```bash
./run.sh
cd desktop/macos && ./run.sh
```

## 验证项

- [x] 安装包右键打开后，离线字幕可用
- [x] 观看场景可在主窗口 / 设置中切换
- [x] 暂停约 2.5s 后旧字幕自动清空
- [x] 设置 → 字幕记录可写入文件

## 限制

- App 未签名；体积约 1 GB（含 Python 与本地模型）
- 仅 macOS；无 YouTube CC 模式
