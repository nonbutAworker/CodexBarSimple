# Native reset notifications

## Behavior

- A confirmed upcoming regular reset from the existing announcement check submits a native macOS notification titled “Codex 额度即将重置”. Forecasts, completed resets, and banked reset grants do not trigger it.
- Public announcement IDs are saved locally after a successful submission, preventing repeat notifications during later polls or after an app restart.
- Permission requests run asynchronously after the menu bar item is installed. Declining notifications does not disable the orange border, bell, or usage display.
- Startup and an announcement share an in-flight permission request. An announcement withdrawn while permission is pending does not submit a notification.
- Failed submissions remain eligible for retry. Notification presentation and sound still depend on the user's macOS notification and Focus settings.
- Usage polling remains every 60 seconds; announcement polling remains every 600 seconds.

## Automated validation

Validated on an Apple Silicon Mac on September 12, 2026:

- `make test`: passed, 30 tests in 8 suites.
- `make check`: passed, including SwiftFormat lint, debug build, and all 30 tests.
- `swift test --filter ResetNotificationsTests`: passed all 5 notification tests.
- `git diff --check`: passed.

The notification tests inject authorization and submission callbacks instead of accessing the real notification center. They cover successful submission, persistent deduplication, permission denial and recovery, submission failure and retry, concurrent authorization, and cancellation after an announcement is withdrawn. The existing reset API scenario test also verifies the ID exposed to notification handling.

The mocked Codex process test now has a 5-second deadline, matching other process fixtures, instead of a flaky 1-second deadline. Production timeouts are unchanged. No real account or Keychain probes were used for this validation, and no fabricated reset announcement was sent to the user.

## Release and local installation

- Release build completed successfully. The installed bundle reports version 1.4.0, build 6, and its executable is arm64.
- The packaged and installed app passed `codesign --verify --deep --strict` (ad-hoc signing, not Apple notarization).
- The DMG passed `hdiutil verify`; the ZIP was extracted and its app signature, version, and installer syntax were checked. Both archives passed their SHA-256 manifest checks.
- The existing installation command updated the per-user app. Its LaunchAgent was verified running from the installed bundle after the update.
- macOS displayed the native CodexBarSimple notification authorization prompt. After allowing notifications, the installed app logged `Notification permission granted: true` and continued running.
- Native authorization was verified, but a real future announcement's end-to-end banner delivery was not simulated or claimed.
