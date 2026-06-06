# 分支说明

## 活跃分支

| 分支 | 说明 | 适合 |
|------|------|------|
| **main** | 集成主干，已含桌面 MVP | 默认 clone |
| **feat/macapp** | 独立 `.app` + 本地模型按需下载 | macOS 比赛 / 分发 |
| **feat/desktop-client** | 桌面 MVP（依赖仓库 `run.sh`） | 开发调试基线 |

## 归档 / 保底

| 分支 | 说明 |
|------|------|
| **legacy/web-only** | Web 控制台 + Chromium 扩展 + YouTube CC；不含 desktop |

切换浏览器版：

```bash
git checkout legacy/web-only
cp .env.example .env
# .env 中设 VOICEBRIDGE_OPTIONAL_LOCAL_MODELS=0
./run.sh
```

## 合并关系（示意）

```
legacy/web-only ── 浏览器版冻结

main ── PR #22 ── feat/desktop-client (MVP)
  └── feat/macapp (+ 本地模型 + 独立 App)
```

## 本仓库目录与分支

- `desktop/`、`server/`：各分支共享演进
- `extension/`、`static/`：main / feat/macapp 上**归档保留**；完整维护见 `legacy/web-only`
