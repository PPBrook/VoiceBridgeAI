# 分支说明

## 活跃分支

| 分支 | 说明 |
|------|------|
| **feat/macapp** | 独立 `.app` + 本地模型（当前开发） |
| **main** | 集成主干（含桌面 MVP） |
| **feat/desktop-client** | 桌面 MVP 基线（仓库 + `run.sh`） |

## 浏览器版

| 分支 | 说明 |
|------|------|
| **legacy/web-only** | 含 `extension/`、`static/`、YouTube CC；与本分支代码分离 |

```bash
git checkout legacy/web-only
```

本分支（`feat/macapp`）**不含** Web 控制台与浏览器扩展目录。

## 关系示意

```
legacy/web-only     extension/ + static/ + Web UI
feat/macapp         desktop/ + server/（无 extension/static）
main                合并集成
```
