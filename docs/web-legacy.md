# 浏览器版（归档）

本分支（`main` / `feat/macapp`）以 **macOS App** 为主。`extension/` 与 `static/` 目录仍保留在仓库中，但**不在此线活跃开发**。

## 完整浏览器版

请使用分支 **`legacy/web-only`**：

- Web 控制台：`/`、`/config`
- Chromium 扩展：标签页音频 + **YouTube 英文字幕（CC）**
- 本地模型旧行为：`VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=0`

```bash
git checkout legacy/web-only
./run.sh
# Chrome/Edge 加载 extension/
```

## 本分支上的 extension/ / static/

| 目录 | 状态 |
|------|------|
| `extension/` | 只读归档；协议仍见 [extension/API.md](../extension/API.md) |
| `static/` | 开发模式 `./run.sh` 仍可访问；独立 App 不打包 |

桌面 App 与扩展 **共用** `server/` 与 WebSocket 协议，但不实现 YouTube CC 抓取。

## 文档

- [extension/README.md](../extension/README.md)
- [extension/API.md](../extension/API.md)
