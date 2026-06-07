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

体积更小（约 24 MB），**不含** Whisper/Argos，默认使用云端 ASR/翻译（安装包内已合并演示用 API 配置）。

1. 下载 [releases/VoiceBridgeAI-Cloud.zip](../releases/VoiceBridgeAI-Cloud.zip)（Git LFS，约 25 MB）
   - 在 **GitHub 网页**打开链接 → 点右上角 **Download**（勿复制 raw 链接到浏览器）
   - 若 clone 仓库：执行 `git lfs pull`
   - 下载后校验：`file VoiceBridgeAI-Cloud.zip` 应显示 `Zip archive`；体积约 25 MB（不是 133 B 或几百 KB 的 HTML/LFS 指针）
   - SHA256 见 [releases/SHA256SUMS](../releases/SHA256SUMS)
2. 解压 → **右键打开** `VoiceBridgeAI-Cloud.app`
3. 其余步骤同上（屏幕录制 → 开始字幕）

配置目录：`~/Library/Application Support/VoiceBridgeAI-Cloud/`

### 无法解压 zip（提示已损坏）

常见原因是**下到错误文件**（不是真正的 zip）：

| 实际大小 | 可能原因 |
|----------|----------|
| ~133 B，内容为 `version https://git-lfs.github.com/...` | clone 后未执行 `git lfs pull` |
| ~300 KB，用文本打开是 HTML | 用了 raw 直链或 404 页面，需在 GitHub 文件页点 **Download** |
| 与 [SHA256SUMS](../releases/SHA256SUMS) 不一致 | 下载不完整，请重新下载 |

终端校验示例：

```bash
file ~/Downloads/VoiceBridgeAI-Cloud.zip
shasum -a 256 ~/Downloads/VoiceBridgeAI-Cloud.zip
# 应与 releases/SHA256SUMS 中 VoiceBridgeAI-Cloud.zip 一致
```

也可在终端解压：`ditto -xk ~/Downloads/VoiceBridgeAI-Cloud.zip ~/Desktop/`

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
  releases/VoiceBridgeAI-Cloud.zip   # 云端版（较小）
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
