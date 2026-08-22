# CodexBarSimple

[English](README.md) | **简体中文**

一个专注于 Codex 剩余额度的极简 macOS 菜单栏工具。无需打开窗口，抬眼就能看到百分比。

![CodexBarSimple 菜单栏](Validation/persistent-menu-card.png)

## 一键安装

要求：Apple Silicon Mac、macOS 14 或更高版本，以及已经安装并登录的 Codex CLI。

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nonbutAworker/CodexBarSimple/main/install.sh)"
```

安装脚本会：

- 从最新 GitHub Release 下载 Apple Silicon 安装包并校验 SHA-256；
- 把应用安装到 `~/Applications/CodexBarSimple.app`；
- 仅移除该应用自身的下载隔离属性，不会关闭系统 Gatekeeper；
- 注册用户级 LaunchAgent 并立即启动；
- 不需要管理员权限或 Apple 开发者账号。

本项目暂时没有 Developer ID 签名或 Apple 公证，因此 macOS 可能拒绝直接打开下载的 `.app`。请使用上面的
开源安装脚本，也可以先阅读 [`install.sh`](install.sh) 再执行。SHA-256 可以发现下载损坏，但不能代替
Developer ID 的发布者身份验证。

也可以从 [Releases](https://github.com/nonbutAworker/CodexBarSimple/releases/latest) 手动下载 DMG，挂载后在终端运行：

```bash
/bin/zsh "/Volumes/CodexBarSimple Installer/安装并启动.command"
```

## 产品特性

- 菜单栏永久显示 Codex 剩余百分比、`Codex left` 标签和竖向用量线；
- 启动后立即读取，随后每分钟自动刷新；
- 剩余量低于 `10%` 时，数字和用量线同步变为错误红色；
- 已观察到的额度从非 `100%` 回到 `100%` 时，数字短暂放大并变绿；
- 左键点击没有任何反应，右键菜单只有 `Quit`；
- 没有 Dock 图标、设置窗口、账号管理、分析或遥测。

额度重置动画峰值：

![额度重置动画峰值](Validation/reset-animation-peak.png)

## 工作原理与隐私

CodexBarSimple 沿用 [CodexBar](https://github.com/steipete/CodexBar) 的只读 Codex CLI 数据链路：

1. 查找本机 Codex CLI；
2. 启动 `codex -s read-only -a untrusted app-server`；
3. 通过本地 JSON RPC 调用 `account/rateLimits/read`；
4. 根据 `usedPercent` 计算剩余百分比，并通过 `NSStatusItem` 渲染到菜单栏。

应用不会读取或修改 `~/.codex/auth.json`，不会访问 macOS 钥匙串，也不会把用量数据发送给第三方。
Codex 的登录和令牌生命周期仍完全由 Codex CLI 管理。

## 卸载

```bash
launchctl bootout "gui/$(id -u)/app.codexbarsimple.CodexBarSimple" 2>/dev/null || true
rm -rf "$HOME/Applications/CodexBarSimple.app"
rm -f "$HOME/Library/LaunchAgents/app.codexbarsimple.CodexBarSimple.plist"
```

这些命令只会停止并删除当前用户的 CodexBarSimple 应用和登录服务。

## 从源码构建

```bash
git clone https://github.com/nonbutAworker/CodexBarSimple.git
cd CodexBarSimple
make check
make package
open CodexBarSimple.app
```

开发要求：macOS 14+、Apple Silicon 和 Swift 6.2+。默认测试使用本地 Stub，不访问真实账号；只有显式设置
`CODEXBAR_SIMPLE_LIVE_TESTS=1` 才会读取当前已登录 Codex 账号的真实用量。

## 致谢

- [CodexBar](https://github.com/steipete/CodexBar)：核心实现思路和部分 MIT 许可代码；
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/)：菜单栏数字字体，使用 SIL Open Font License 1.1；
- TRAE / Nimbus Core 设计素材：菜单栏卡片的颜色、排版、间距和圆角参考。

完整第三方声明见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。本项目是独立社区项目，与 OpenAI
及 CodexBar 项目没有隶属或背书关系。

## License

[MIT](LICENSE)
