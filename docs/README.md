# 文档索引

| 文档 | 内容 |
|------|------|
| [development.md](development.md) | 开发流程、数据目录、字幕记录、故障排查 |
| [architecture.md](architecture.md) | 数据流、观看场景、侧车与 macOS 模块 |

代码说明见各目录 README：

- [../README.md](../README.md) — 项目总览
- [../server/README.md](../server/README.md) — Python 引擎与 API
- [../desktop/README.md](../desktop/README.md) — macOS App 结构

**当前主分支**：macOS App + Python 侧车（`main` / `feat/macapp`）。

### 功能速查

| 功能 | 位置 |
|------|------|
| 观看场景 | 主窗口 / 设置 → 引擎 |
| 本地模型 | 设置 → 本地模型 |
| 接口密钥 | 设置 → 接口密钥 |
| 字幕记录 | 设置 → 字幕记录；悬浮栏「记」 |
| 透明度 / EN | 悬浮字幕顶栏 |

其它分支（按需 checkout，根目录不一定包含对应代码）：

- `legacy/web-only` — 旧浏览器版
- `feat/chrome-extension` — Chrome 扩展实验
