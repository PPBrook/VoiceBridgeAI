# VoiceBridgeAI

macOS 原生 App：系统英文音频 → 实时中文悬浮字幕。

## Demo 视频

带配音的功能演示，覆盖系统音频采集、实时悬浮字幕、三层引擎（ASR → 句中翻译 → 句末润色）、观看场景、字幕记录与 Local/Cloud 变体：

**[哔哩哔哩观看 →](https://www.bilibili.com/video/BV1C4Et6PESe/)**

> Demo 仅演示 **macOS 端**。Windows 客户端在 `feat/winapp` 分支有初步实现，因时间有限未做充分测试与录制。

## 逾期修复说明（2026-06-08）

截止前时间管理不足：安装包从 GitHub 下载后解压损坏的问题在多次提交中反复出现，最后一次提交时**未能本地验证「下载 → 解压 → 打开」全流程**，导致评审可能拿到不完整或不可用的 zip。

本次逾期修复：重新打包并校验（Local ~1.2 GB），打包脚本增加完整性检查；构建时移除 Python 3.14 venv 的 `𝜋thon` 等非 ASCII 别名（Finder 解压 zip 对此敏感）。对因此给评审带来的不便深表歉意。

**评审请务必：**

1. `git lfs pull` 拉取完整 zip
2. 终端执行 `ditto -xk releases/VoiceBridgeAI-Local.zip .` 解压（**勿** Finder 双击 zip）
3. `xattr -cr VoiceBridgeAI-Local.app` 后 **右键 → 打开**

## 安装试用

仓库 [`releases/`](releases/) 提供 **zip 打包安装包**（Git LFS）：

| 版本 | 文件 | 体积 | 说明 |
|------|------|------|------|
| **Local**（推荐） | [VoiceBridgeAI-Local.zip](releases/VoiceBridgeAI-Local.zip) | ~1.2 GB | 内置 Whisper + Argos，离线可用 |
| **Cloud** | [VoiceBridgeAI-Cloud.zip](releases/VoiceBridgeAI-Cloud.zip) | ~70 MB | 仅云端 ASR/翻译 |

### ⚠️ 必须用终端解压（勿双击 zip）

> **Finder /「归档实用工具」双击解压，大概率导致 `.app` 损坏**（提示「已损坏，无法打开」）。**请务必在终端执行以下命令。**  
> 若 zip 体积明显偏小（Local 应约 **1.2 GB**），说明文件不完整或 LFS 未拉取，请 `git lfs pull` 或重新 clone。

```bash
git clone https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git lfs pull    # 必须：否则 zip 只有几 KB 的 LFS 指针

# 必须：终端解压（推荐 ditto）
ditto -xk releases/VoiceBridgeAI-Local.zip .
# Cloud 版：ditto -xk releases/VoiceBridgeAI-Cloud.zip .

xattr -cr VoiceBridgeAI-Local.app
open VoiceBridgeAI-Local.app
```

**禁止：** 在 Finder 中双击 zip、拖入「归档实用工具」解压。  
**备选：** `unzip -q releases/VoiceBridgeAI-Local.zip`（解压后同样执行 `xattr -cr`）。

只拉 zip（sparse checkout）：

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/PPBrook/VoiceBridgeAI.git
cd VoiceBridgeAI
git sparse-checkout set releases/VoiceBridgeAI-Local.zip
git checkout
git lfs pull
ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
```

**快速开始：** 终端解压 → `xattr -cr` → **右键 → 打开** App → 授予**屏幕录制** → **开始悬浮字幕**

### 为什么必须用终端解压？

本 App 内置 Python 3.14 虚拟环境（`python-venv/`）。打包时我们已做以下处理，但**评审侧仍须用终端解压**：

| 问题 | 说明 |
|------|------|
| **Python 3.14 `𝜋thon` 别名** | venv 会生成 Unicode 文件名 `𝜋thon`（数学 italic π + thon）。Finder /「归档实用工具」解压含此类路径或超大 zip 时，容易损坏 `.app`。构建脚本 `sanitize-venv-bin.sh` 会在打包前移除该别名。 |
| **Git LFS 指针** | clone 后若未 `git lfs pull`，zip 可能只有几 KB 指针文件，解压必失败。 |
| **zip 不完整** | 上传中断会导致 zip 缺尾部（如 Local 仅 ~240 MB 而非 ~1.2 GB），`unzip -t` 会报错。 |

**如何确认 zip 完整：**

```bash
git lfs pull
ls -lh releases/VoiceBridgeAI-Local.zip   # 应约 1.2 GB
unzip -t releases/VoiceBridgeAI-Local.zip | tail -1   # 应显示 No errors
```

**正确解压流程（再次强调）：**

```bash
ditto -xk releases/VoiceBridgeAI-Local.zip .
xattr -cr VoiceBridgeAI-Local.app
# 右键 → 打开（非双击）
```

若提示「已损坏」：先确认 zip 体积与 `unzip -t`，再确认**未用 Finder 双击解压**；删除损坏的 `.app` 后按上述命令重来。

详细步骤与故障排查：[docs/submission.md](docs/submission.md)

## 源码开发

```bash
cp .env.example .env
./run.sh                          # 终端 1：Python 引擎
cd desktop/macos && ./run.sh      # 终端 2：Swift UI
```

构建独立 App：`desktop/macos/build-app-{local,cloud}.sh` → `dist/`；打包发布见 `scripts/publish-release.sh`。

## 文档

| 文档 | 内容 |
|------|------|
| [docs/submission.md](docs/submission.md) | 评审 / 试用说明 |
| [docs/development.md](docs/development.md) | 开发流程与排错 |
| [docs/architecture.md](docs/architecture.md) | 架构与数据流 |
| [server/README.md](server/README.md) | Python 引擎 API |
| [desktop/README.md](desktop/README.md) | macOS 构建 |

完整索引：[docs/README.md](docs/README.md)
