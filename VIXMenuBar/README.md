# VIXMenuBar（模块说明）

这是应用源代码所在的模块目录。完整的项目介绍、安装与使用、常见问题等文档请查看仓库根目录的 README：参见 ../README.md。

简述：使用 SwiftUI + AppKit 构建的 macOS 菜单栏应用，显示 VIX（恐慌指数）最新数值（数据来自 Yahoo Finance），默认每 60 秒自动刷新，支持手动刷新。

---

快速开始（开发者）

先决条件
- macOS（建议 macOS 12+ 或更高）
- Xcode（建议 Xcode 14+）

在 Xcode 中构建与运行
1. 在 Xcode 中打开本项目（打开 `VIXMenuBar.xcodeproj`）。
2. 选择目标 `VIXMenuBar`，确保运行目标为你的 Mac（My Mac）。
3. 点击 Run（⌘R）启动应用。应用会在菜单栏创建图标并尽快拉取数据（默认间隔 60 秒）。

---

功能说明
- 菜单栏图标 + 最新数值显示
- 弹出面板显示最新数值、更新时间、手动刷新与退出按钮
- 周期性自动刷新（默认为 60 秒），并支持手动刷新

隐私与数据来源
- 应用仅使用 Yahoo Finance 的公开接口（https://query1.finance.yahoo.com）获取公开行情数据，不会收集或上报本地用户数据。

贡献
- 欢迎提交 Issue 与 Pull Request。

---
