CodexBarSimple 1.4.1 (Apple Silicon)

Recommended installation:
1. Open Terminal.
2. Paste the following command and press Return:

   /bin/zsh "/Volumes/CodexBarSimple Installer/Install CodexBarSimple.command"

3. The script installs the app to your user Applications folder, registers a per-user login service, and starts it.
4. Make sure the Codex CLI is installed and signed in, or that the ChatGPT macOS app containing the CLI is signed in.
5. Your remaining Codex usage will appear directly in the menu bar.
6. Allow notifications when macOS asks to receive upcoming-reset reminders in Notification Center.

Important:
This community build does not have a Developer ID signature or Apple notarization. The installation command checks
the app bundle, removes quarantine only from CodexBarSimple.app, and does not disable or modify Gatekeeper globally.
Administrator privileges are not required.

Install location: ~/Applications/CodexBarSimple.app
Login service: ~/Library/LaunchAgents/app.codexbarsimple.CodexBarSimple.plist

Controls:
- Left click does nothing.
- Right click opens a menu containing only Quit.
- Usage refreshes at launch and once every minute.
- The percentage has no text label. A small bell appears only for a confirmed upcoming reset; it swings for
  one minute per new announcement, then stays still until the announcement ends.
- Reset announcements are checked at launch and every 10 minutes. An orange border means a regular reset is
  explicitly announced and awaiting execution. Forecasts and banked reset credits do not trigger the border.
- Confirmed upcoming resets also send a native macOS notification, once per announcement even after restarting.
  If permission is denied, the menu bar still works. Notifications follow your macOS notification and Focus settings.
  When available, the notification includes the scheduled reset date and time in your Mac's local time zone.
- When the normal Codex quota is exhausted, Luna Reserve appears with a moon icon and gold usage bar.
- Below 10%, the number and usage bar turn red.
- When the quota returns to 100%, the number briefly grows and turns green.

System requirements: macOS 14 or later on Apple Silicon.
