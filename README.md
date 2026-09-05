# CodexBarSimple

**English** | [简体中文](README.zh-CN.md)

A tiny macOS menu bar utility that keeps your remaining Codex usage visible at a glance. No window to open,
no dashboard to check—just the percentage in the menu bar.

![CodexBarSimple menu bar](Validation/persistent-menu-card.png)

## One-command install

Requirements: an Apple Silicon Mac running macOS 14 or later, with the Codex CLI installed and signed in.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/nonbutAworker/CodexBarSimple/main/install.sh)"
```

The installer:

- downloads the Apple Silicon package from the latest GitHub Release and verifies its SHA-256 checksum;
- installs the app to `~/Applications/CodexBarSimple.app`;
- removes quarantine only from this app—it does not disable Gatekeeper system-wide;
- registers a per-user LaunchAgent and starts the app immediately;
- requires neither administrator privileges nor an Apple Developer account.

CodexBarSimple does not currently have a Developer ID signature or Apple notarization. macOS may therefore refuse
to launch a downloaded `.app` directly. Use the open-source installer above, or inspect [`install.sh`](install.sh)
before running it. The checksum protects against a corrupted download; it is not a substitute for Developer ID
publisher verification.

For a manual installation, download the DMG from [Releases](https://github.com/nonbutAworker/CodexBarSimple/releases/latest),
mount it, and run this command in Terminal:

```bash
/bin/zsh "/Volumes/CodexBarSimple Installer/Install CodexBarSimple.command"
```

## Features

- Keeps the remaining Codex percentage, `Codex left` label, and a vertical usage bar permanently visible.
- Refreshes immediately at launch and then once every minute.
- When the normal Codex quota is exhausted, switches to Luna Reserve with a moon icon, gold percentage, and usage bar; normal quota remains the priority whenever it is above `0%`.
- Turns both the number and usage bar red below `10%` remaining.
- When an observed quota jumps from below `100%` back to `100%`, briefly enlarges the number and turns it green.
- Ignores left clicks; the right-click menu contains only `Quit`.
- Has no Dock icon, settings window, account manager, analytics, or telemetry.

Quota-reset animation at its peak:

![Quota reset animation peak](Validation/reset-animation-peak.png)

## How it works and privacy

CodexBarSimple follows the read-only Codex CLI approach used by
[CodexBar](https://github.com/steipete/CodexBar):

1. Locate the Codex CLI installed on the Mac.
2. Start `codex -s read-only -a never app-server`.
3. Call `account/rateLimits/read` over local JSON RPC.
4. Calculate the remaining percentage from `usedPercent`; when the normal window is exhausted, use the
   `base_model_inference` Luna Reserve window and render it in an `NSStatusItem`.

The app does not read or modify `~/.codex/auth.json`, access the macOS Keychain, or send usage data to a third
party. Authentication and token management remain entirely under the Codex CLI.

## Uninstall

```bash
launchctl bootout "gui/$(id -u)/app.codexbarsimple.CodexBarSimple" 2>/dev/null || true
rm -rf "$HOME/Applications/CodexBarSimple.app"
rm -f "$HOME/Library/LaunchAgents/app.codexbarsimple.CodexBarSimple.plist"
```

These commands stop and remove only CodexBarSimple and its per-user login service.

## Build from source

```bash
git clone https://github.com/nonbutAworker/CodexBarSimple.git
cd CodexBarSimple
make check
make package
open CodexBarSimple.app
```

Development requirements: macOS 14+, Apple Silicon, and Swift 6.2+. The default test suite uses local stubs and
does not access a real account. Set `CODEXBAR_SIMPLE_LIVE_TESTS=1` only when you explicitly want to test against
the currently signed-in Codex account.

## Acknowledgements

- [CodexBar](https://github.com/steipete/CodexBar) for the core approach and selected MIT-licensed code.
- [JetBrains Mono](https://www.jetbrains.com/lp/mono/) for the menu bar font, licensed under the SIL Open Font
  License 1.1.
- The supplied TRAE / Nimbus Core design references for the card's color, typography, spacing, and radius tokens.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for complete notices. CodexBarSimple is an independent
community project and is not affiliated with or endorsed by OpenAI or the CodexBar project.

## License

[MIT](LICENSE)
