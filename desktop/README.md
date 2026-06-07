# Desktop 客户端

| 平台 | 目录 | 技术栈 | 状态 |
|------|------|--------|------|
| macOS | [macos/](macos/) | Swift + AppKit + ScreenCaptureKit | ✅ 主分支维护 |
| Windows | [windows/](windows/) | C# / WinUI（规划）+ WASAPI | 🚧 `feat/winapp` |

两端共用 **同一 Python 引擎**（`server/`）：`http://127.0.0.1:8765` + `ws://127.0.0.1:8765/ws`。

## 开发入口

```bash
# macOS
./run.sh && cd desktop/macos && ./run.sh

# Windows (PowerShell)
.\run.ps1
# 客户端 UI 见 desktop/windows/（开发中）
```

- macOS 说明：[macos/README.md](macos/README.md)
- Windows 说明：[windows/README.md](windows/README.md) · [docs/windows.md](../docs/windows.md)
