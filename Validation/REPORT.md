# CodexBarSimple 功能验收报告

验收日期：2026-08-05
最终结果：**通过**

## 产品范围

CodexBarSimple 是以零操作查看为核心的菜单栏监视器：

- 唯一界面是常驻于 macOS 菜单栏的 TRAE 用量卡片
- 直接显示大号剩余百分比、`Codex left` 和对应高度的竖向用量线
- 剩余量低于 10% 时，百分比文字与竖向用量线同步切换为 TRAE 错误红色
- 已观察到的额度从非 100% 跳到 100% 时，数字变绿并从 14 pt 放大至菜单栏内可完整容纳的 16 pt，短暂停留后平滑恢复
- 左键点击完全无响应，不打开任何界面
- 右键点击仅显示单一 macOS 原生 `Quit` 菜单项
- 启动时读取一次，之后每 1 分钟后台自动更新

常驻卡片渲染：[`persistent-menu-card.png`](persistent-menu-card.png)
额度重置动画峰值：[`reset-animation-peak.png`](reset-animation-peak.png)

## 环境

- macOS 26.5.1（Build 25F80）
- Apple Silicon / arm64
- Codex CLI `0.146.0-alpha.3.1`
- CodexBar 只读基准 CLI `0.45.2`
- 真实 Codex 登录状态可用

## 数据与计算

| 检查项 | 结果 | 证据 |
| --- | --- | --- |
| 目标应用真实 Codex 读取 | 通过 | 目标应用自己的 `CodexUsageClient` |
| 窗口选择 | 通过 | 主窗口缺失时回退至 10080 分钟周窗口 |
| 百分比计算 | 通过 | 最终真实读取已用 42%，应用显示剩余 58% |
| CodexBar 交叉核对 | 通过 | 基准同时返回 `secondary.usedPercent = 42` |
| 只读调用 | 通过 | `codex -s read-only -a untrusted app-server` |

## 常驻展示与右键菜单

| 检查项 | 结果 |
| --- | --- |
| 关闭其他界面时完整卡片持续可见 | 通过 |
| 左键点击不打开窗口或菜单 | 通过 |
| 右键菜单仅包含 `Quit` | 通过 |
| 刷新期间重复请求受并发保护 | 通过 |
| 点击 `Quit` 终止进程 | 通过 |
| 实时值和竖向用量线同步变化 | 通过 |
| `< 10%` 使用红色、`10%` 保持正常配色 | 通过 |
| 非 100% → 100% 只触发一次绿色放大恢复动画 | 通过 |
| 首次读到 100% 或连续读到 100% 不误触发 | 通过 |
| macOS 辅助功能值为实时百分比 | 通过 |
| 连续启动仍只有一个进程 | 通过 |

卡片尺寸为 80 × 22 pt，在当前 Retina 屏幕上渲染为 160 × 44 px。百分比采用 14 pt，既保持
主视觉，又在上下保留约 1.8 pt 的字体行高余量；`Codex left` 为 5 pt，避免与主数字比例失衡。
右侧用量线收窄至 1.5 pt、缩短至 16 pt；80 pt 宽度也确保最宽的 `100%` 状态仍有呼吸空间。
重置动画以约 0.24 秒放大、0.9 秒停留、0.4 秒恢复；只有动画期间进行短时帧重绘，不改变日常空闲负载。

## 后台刷新与错误恢复

- 启动后立即读取真实账号
- 每 1 分钟自动重复读取
- 实机监控确认启动探测与约 60 秒后的第二轮探测均启动只读 Codex app-server
- 首次读取失败时显示 `--%`
- 已有结果后刷新失败时保留上次百分比
- 后续读取恢复时自动更新为最新百分比
- 失败结果不参与重置判定；只有先存在有效旧值、随后有效显示值变成 100% 才触发动画

这些行为通过模型级 Stub 测试完成，不修改真实登录、认证文件或钥匙串。

## Release 启动与资源性能

当前机器连续启动 10 次，使用外部墙钟从 `open -n` 开始计时：

| 指标 | 最小值 | 平均值 | P95 / 最大值 |
| --- | ---: | ---: | ---: |
| 进程出现 | 45 ms | 71 ms | 88 ms / 88 ms |
| 菜单栏卡片出现 | 163 ms | 216 ms | 256 ms / 256 ms |
| 真实百分比就绪 | 890 ms | 1.07 s | 1.25 s / 1.25 s |

百分比就绪时间包含启动 Codex 只读 app-server 及账户数据返回；菜单栏卡片本身不会等待该查询。首次查询完成后：

- 连续 11 次空闲采样 CPU 为 0.0%–0.1%
- 稳态物理内存约 22 MB；启动期间记录到的瞬时峰值为 114 MB
- Release `.app` 为 736 KB，主可执行文件为 454,688 bytes

## 自动化与包体

- `swift format lint --recursive --strict Sources Tests`：通过
- `swift build`：通过
- `swift test`：16 项测试、6 个测试套件全部通过
- 显式真实账号测试：
  `LIVE_CODEX_USAGE kind=weekly used=42.0 remaining=58%`
- Release 应用：`CodexBarSimple.app`
- Mach-O：arm64
- 最低系统：macOS 14
- `LSUIElement = true`
- `LSMultipleInstancesProhibited = true`
- 代码签名深度校验：通过
- 仅依赖 macOS 系统 Framework
- 仅打包常驻卡片实际使用的 JetBrains Mono SemiBold 字体资源
- 安装版优先从自身 `Contents/Resources` 读取字体，不依赖开发机 `.build` 目录
- 未发现 CodexBarSimple 崩溃报告
- 原始 CodexBar 参考仓库保持只读，`git status` 为空

## 内部命令安装包

- 命令安装版磁盘卷名：`CodexBarSimple Installer`
- 在带 `com.apple.quarantine` 的 DMG 副本中执行安装命令：通过
- 安装位置：`~/Applications/CodexBarSimple.app`
- 用户级登录服务：`~/Library/LaunchAgents/app.codexbarsimple.CodexBarSimple.plist`
- 不需要管理员权限，不修改系统 Gatekeeper，只清除目标应用自身的下载隔离属性
- LaunchAgent 直接运行 arm64 应用可执行文件：通过
- 安装后状态：`running`；低用量红色版菜单栏辅助功能值：`Codex 剩余用量 | 4%`
- 正常退出后状态：`not running`，`last exit code = 0`，不会被自动重启
