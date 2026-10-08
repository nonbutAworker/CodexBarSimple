# Desktop CLI discovery repair (1.4.2)

## Reproduction and cause

On October 8, 2026, version 1.4.1 could not discover the Codex CLI with the standard macOS login-service PATH (`/usr/bin:/bin:/usr/sbin:/sbin`). The opt-in real-account usage test failed with `cliNotFound`.

The installed ChatGPT desktop app bundles Codex CLI 0.160.1 at `Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`. The old fallback only checked `Contents/Resources/codex`. The terminal could find the new binary through its PATH, masking the background-service failure.

With an explicit override pointing at the current bundled binary, the same usage request succeeded. After adding the current desktop bundle locations, it succeeded with the standard login-service PATH and without an override.

## Change and regression coverage

- Discover the current nested CLI bundle inside ChatGPT and Codex desktop apps, for both user and system installations.
- Retain standalone CLI, explicit override, PATH, and legacy desktop discovery behavior.
- Record local usage-refresh success, failures, and changed menu-render values. No account identities, credentials, browser cookies, or raw API responses are logged.
- Mocked filesystem tests exercise eight current/legacy bundle locations with only the background-service PATH and verify that explicit overrides and PATH installations retain precedence.

`make test` and `make check` passed all 36 tests in 9 suites, including formatting checks and a debug build. The release build passed. The user explicitly requested fixing live usage and reinstalling, so the opt-in real-account test was used to reproduce and verify this issue; it does not run in the default suite.

## Clean local installation

The old installed app, generated development bundle, LaunchAgent, and app preferences were removed from their active locations. Backups were moved to the user's Trash, and the old mounted 1.0.0 installer was ejected. Codex login credentials and the source repository were preserved.

The repaired 1.4.2 app (build 8) was installed and its per-user LaunchAgent was verified running. Its actual process logged successful usage refreshes at startup and again after the one-minute interval, using the standard service PATH with no manually configured CLI override. Native notification authorization remained granted.

The final release build's native menu-render path also logged the initial unavailable image and the subsequent percentage image at 12:34:45–12:34:46. This log is emitted after assigning a non-nil rendered image to the real status button and updating its accessibility value. The first live fetch and menu update completed in approximately one second. Only one app process was running, and its executable matched the packaged binary byte for byte. UI automation could not capture the menu-only process, so no visual screenshot is claimed.

The final DMG passed `hdiutil verify`; the ZIP was extracted and its app signature, arm64 executable, and installer syntax were verified. Both archives passed their SHA-256 manifest checks.
