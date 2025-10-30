# VIXMenuBar

VIXMenuBar 是一个轻量的 macOS 菜单栏应用，用来在菜单栏和弹出面板中展示 VIX（恐慌指数）最新数值。应用会定时从 Yahoo Finance 获取数据并显示在状态栏，点击图标可以展开弹出面板查看详情（最新值、更新时间、刷新与退出按钮）。

功能
- 菜单栏图标 + 实时数值显示
- 弹出面板展示最新数值与更新时间
- 自动周期拉取（默认 60 秒）和手动刷新
- 支持自定义菜单栏图标（放入 Assets.xcassets 中的 `VIXIcon`）

注意：本项目只是读取公开的 Yahoo Finance 接口，不收集用户隐私数据。

快速开始（开发者）

前提
- macOS（建议使用较新版本的 macOS）
- Xcode（建议 Xcode 14+）

构建并运行
1. 在 Finder 中打开本仓库，双击 `VIXMenuBar.xcodeproj` 或在 Xcode 中打开项目。
2. 选择目标 `VIXMenuBar`，连接一个 macOS 运行目标（默认为 My Mac）。
3. 点击 Run（或使用 ⌘R）启动应用。首次启动会在菜单栏创建一个图标并尽快拉取数据。

替换或自定义图标
- 项目中会优先使用 `Assets.xcassets` 中名为 `VIXIcon` 的资源（如果存在）。否则会回退到 SF Symbol `chart.line.uptrend.xyaxis`。
- 推荐使用单个向量 PDF（Template Image），或准备 PNG：菜单栏图标建议使用 18×18pt（@2x 为 36×36px）。
  - 推荐做法：在 `Assets.xcassets` 新建 Image Set，命名为 `VIXIcon`，将 `Render As` 设置为 `Template Image`（或者使用 PDF 并勾选 Preserve Vector Data）。
- 修改后在 Xcode 中重新构建即可看到新图标。

打包与分发（给最终用户）

1. 签名与沙盒
   - 若你希望在 App Store 或带沙盒的环境下发布，请在 Xcode 的 Signing & Capabilities 中添加适当的签名证书并启用 `App Sandbox`。
   - 如果启用了 `App Sandbox`，请在 `Capabilities` 中勾选 `Outgoing Connections (Client)`（`com.apple.security.network.client`），否则网络访问（URLSession）会被拒绝并报 `Operation not permitted`。

2. 代码签名与公证（推荐）
   - 为避免 Gatekeeper 阻止用户运行，建议使用你的 Developer ID 对应用进行代码签名并完成 Apple 的公证流程（notarize）。
   - 简单签名步骤（示例）：

```bash
# 本地签名（请替换为你的开发者 ID）
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name (TEAMID)" /path/to/VIXMenuBar.app

# 将应用提交给 Apple 公证（需要 Xcode / altool / notarytool 配置）
# 请参考 Apple 官方文档进行 notarize 步骤
```

3. 未签名应用或来自“未知来源”的提示
- 如果你直接把未签名的 `.app` 发给用户，macOS Gatekeeper 可能阻止打开并在“安全性与隐私”中显示“已阻止来自不明开发者的应用”。
- 常见允许方法（用户端）：
  1. 在 Finder 中选中 `VIXMenuBar.app`，按住 Control 键点击（或右键）→ 选择「打开」。
  2. 系统会弹出确认对话框，点击「打开」。这会把该应用标记为已认可，之后可以正常打开。
  3. 如果应用已经被阻止，可去：系统设置 → 隐私与安全 → 在 "通用"（General）区域找到 “仍要打开”/“允许” 的按钮并点击。

- 另一个临时方法（高级用户/开发者）：

```bash
# 移除文件的 quarantine 标记（使系统认为是本地可信文件）
xattr -r -d com.apple.quarantine /path/to/VIXMenuBar.app

# 或者在终端中允许该应用（将其加入受信任列表）
spctl --add /path/to/VIXMenuBar.app
```

注意：这些命令会改变系统对应用的信任处理；仅在你信任该应用时使用。长期发布建议使用正式的代码签名与公证流程。

常见问题与排查

1. 启动后出现网络权限错误（示例：NSPOSIXErrorDomain Code=1 "Operation not permitted"）
   - 原因：App 启用了 App Sandbox，但没有 entitlements 中的 `com.apple.security.network.client`。
   - 解决：在 Xcode 的 Signing & Capabilities 中确保 `App Sandbox` 已启用且勾选 `Outgoing Connections (Client)`，或者在你的 `.entitlements` 中加入：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

2. 菜单栏图标显示 `--` 或不更新
   - 检查控制台日志：应用在启动时会打印诊断信息（包括 network client entitlement、system proxy settings、以及 fetch 的错误信息）。
   - 确保网络可用，并确认是否有本地代理（127.0.0.1:xxx）或 VPN 干扰网络请求。

3. 菜单栏图标没有显示自定义图标
   - 确认 `Assets.xcassets` 中存在名为 `VIXIcon` 的 Image Set，且类型为 Template 或 使用 PDF。
   - 清理缓存并重启应用（在 Xcode 中 Clean，然后重新运行）。

隐私与数据来源说明

- 本应用只从 Yahoo Finance 的公开 API（query1.finance.yahoo.com）获取公开行情数据，不收集或上传任何本地用户数据。
- 若你修改或扩展数据来源，请在 README 或应用内告知用户并遵守相应服务的使用条款。

贡献与发布

欢迎提交 issue 与 PR。常见改进方向：
- 添加更多指数/股票支持
- 自定义刷新间隔或通知提醒
- 更好的图标与深色模式适配

许可证

本项目默认使用 MIT 许可证（你可以根据需要修改）。

---

如果你希望我生成一个示例 `VIXIcon`（SVG/PDF/PNG），或者把 README 翻译成英文版、增加发布（release）流程脚本，我可以继续帮你生成或写出示例资源和脚本。