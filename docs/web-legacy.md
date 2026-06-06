# 浏览器版（legacy/web-only）

本分支 **已删除** `extension/` 与 `static/`。完整浏览器版仅在：

**分支 `legacy/web-only`**

包含：

- `extension/` — Chromium 扩展（标签页音频 + YouTube CC）
- `static/` — Web 控制台（`/`、`/config`）
- 本地模型旧行为：`VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=0`

```bash
git checkout legacy/web-only
cp .env.example .env
./run.sh
```

WebSocket 协议在本分支见 [websocket-api.md](websocket-api.md)；legacy 分支见 `extension/API.md`。
