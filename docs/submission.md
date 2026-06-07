# 作品提交说明

面向评审老师：clone 或 sparse-checkout 后**直接使用 `.app`**，无需配置 Python、无需下载模型、**无需解压 zip**。

## 快速试用（Local 推荐）

1. 获取 `releases/VoiceBridgeAI-Local.app`（约 1.2 GB，**不压缩**）
2. 拖入「应用程序」，或：

```bash
cp -R releases/VoiceBridgeAI-Local.app ~/Applications/
xattr -cr ~/Applications/VoiceBridgeAI-Local.app
open ~/Applications/VoiceBridgeAI-Local.app
```

3. **右键** App → **打开**（未签名，首次不能双击）
4. **系统设置 → 隐私与安全性 → 屏幕录制** → 勾选 VoiceBridgeAI
5. 播放含英文的系统音频（如浏览器视频）→ **开始悬浮字幕**

**已内置：** Whisper 离线识别、Argos 离线翻译、演示用云端 API 配置。  
配置与日志：`~/Library/Application Support/VoiceBridgeAI-Local/`

**系统要求：** macOS 13+

### 云端版（可选）

`releases/VoiceBridgeAI-Cloud.app`（约 77 MB），不含本地模型，依赖云端 ASR/翻译。

```bash
cp -R releases/VoiceBridgeAI-Cloud.app ~/Applications/
xattr -cr ~/Applications/VoiceBridgeAI-Cloud.app
open ~/Applications/VoiceBridgeAI-Cloud.app
```

配置目录：`~/Library/Application Support/VoiceBridgeAI-Cloud/`

### 只下载某一个 App

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.app   # 或 Cloud
git checkout
```

### 无法打开 App

```bash
xattr -cr /path/to/VoiceBridgeAI-Local.app
```

然后再次 **右键 → 打开**。

### 无字幕 / 无声音

- 确认已授予 **屏幕录制** 权限
- 确认系统正在播放英文音频（采集系统声音，不是麦克风）
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
  releases/VoiceBridgeAI-Local.app/   # 离线完整版（不压缩）
  releases/VoiceBridgeAI-Cloud.app/     # 云端版（不压缩）
  server/                               # Python 引擎
  desktop/macos/                        # Swift 客户端
  docs/
```

需要自行编译时，见 [development.md](development.md)、[architecture.md](architecture.md)。

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

- App 未签名
- Local 约 1.2 GB（含 Python 与本地模型）；Cloud 约 77 MB
- 仅 macOS
