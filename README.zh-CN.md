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

- 菜单栏永久显示 Codex 剩余百分比和竖向用量线，不显示文字标签；
- 启动后立即读取，随后每分钟自动刷新；
- 启动时及每 10 分钟检查 [Codex Resets](https://codex-resets.com/api/docs)。已明确公告、等待执行的常规额度重置
  会让卡片显示一圈橙色边框，提醒尽快使用当前剩余额度；
- 确认即将重置时，百分比旁显示 TRAE 小铃铛，前 1 分钟左右摇晃，之后静止保留至公告结束。
  同一条公告的重复检查不会重新播放；
- 正常 Codex 额度耗尽后自动切换到 Luna Reserve，显示月亮图标、金色百分比和金色用量线；正常额度大于 `0%` 时始终优先显示正常额度；
- 剩余量低于 `10%` 时，数字和用量线同步变为错误红色；
- 已观察到的额度从非 `100%` 回到 `100%` 时，数字短暂放大并变绿；
- 左键点击没有任何反应，右键菜单只有 `Quit`；
- 没有 Dock 图标、设置窗口、账号管理、分析或遥测。

额度重置动画峰值：

![额度重置动画峰值](Validation/reset-animation-peak.png)

即将重置的铃铛（循环演示，应用中 1 分钟后停止摇晃）：

![即将重置的铃铛](Validation/reset-bell.gif)

## 工作原理与隐私

CodexBarSimple 沿用 [CodexBar](https://github.com/steipete/CodexBar) 的只读 Codex CLI 数据链路：

1. 查找本机 Codex CLI；
2. 启动 `codex -s read-only -a never app-server`；
3. 通过本地 JSON RPC 调用 `account/rateLimits/read`；
4. 根据 `usedPercent` 计算剩余百分比；正常窗口耗尽时读取 `base_model_inference` 的 Luna Reserve 窗口，
   并通过 `NSStatusItem` 渲染到菜单栏。

应用不会读取或修改 `~/.codex/auth.json`，不会访问 macOS 钥匙串，也不会把用量数据发送给第三方。
Codex 的登录和令牌生命周期仍完全由 Codex CLI 管理。

重置提醒独立读取公开接口 `https://codex-resets.com/api/v1/status`，不携带 Cookie、账号资料或用量数据。
只在 `scheduled_reset` 的 `status` 为 `scheduled` 且 `reset_type` 为 `regular` 时显示橙框；概率预测
（`active_watch`）、已完成的重置和发放 banked reset 券不会触发。预计执行时间已过不代表重置完成，
橙框会保留到接口取消待执行状态。接口无法验证时恢复普通边框，下一次成功检查后重新判断。
每次请求都会跳过本地 HTTP 缓存，避免接口较长的缓存时间延迟提醒。Codex Resets 是第三方公告追踪服务，
并非 OpenAI 官方服务。

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
