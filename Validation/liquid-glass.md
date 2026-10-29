# Native Liquid Glass menu bar

Validated on an Apple Silicon Mac running macOS 26.5.1.

## Implementation

- Replaced the opaque, forced-dark card with native `glassEffect(.regular, in:)` on macOS 26+.
  Regular glass gives text a frosted backing; the initially tested clear variant was too transparent
  in the actual menu bar. Earlier systems retain a native translucent material fallback.
- Kept one live `NSHostingView` inside the existing status button instead of flattening glass into
  an `ImageRenderer` image. Reuse that host for quota changes and existing animations.
- Let normal text and the empty progress track follow the system appearance. Keep the existing
  accent, low-quota red, Luna Reserve gold, orange reminder border, and bell.
- Bind the hosting view to the application's effective appearance and observe changes, rather than
  inheriting the status button's potentially wallpaper-dependent appearance. Both modes retain the
  same regular frosted glass; changing the system theme does not require restarting or refreshing usage.
- Preserve the 80 × 22 pt card, 84 pt status item, font sizes, refresh intervals, and right-click-only
  Quit action. The hosting view passes mouse events through to the existing status button.

## Verification

- `swift test --filter TraeMenuBarUsageRenderingTests`: all 6 focused tests passed, including a live-host
  light → dark → light regression with the parent set to the opposite appearance. Only the test process's
  appearance is changed; no system settings are modified.
- `make check`: formatting, build, and all 39 tests in 9 suites passed. Live-account tests were not enabled.
- `./Scripts/package_app.sh`: release build and ad-hoc signing passed.
- A native QA window using the actual component verified normal, low-quota, reserve, upcoming-reset,
  reset-emphasis, and loading states in light and dark appearances. The screenshot below is of that
  QA window, not an offscreen rendering or a capture of the system menu bar.
- Replaced the installed per-user app with the built bundle and restarted its existing LaunchAgent.
  No Codex account configuration or login data was modified.

![Native Liquid Glass state verification](liquid-glass-states.png)

References: [Apple's custom Liquid Glass guidance](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
and [NSHostingView](https://developer.apple.com/documentation/swiftui/nshostingview).
