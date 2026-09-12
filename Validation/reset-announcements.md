# Reset announcement reminder

Validated on September 12, 2026, for CodexBarSimple 1.2.0.

The app checks the [public status endpoint](https://codex-resets.com/api/v1/status) at launch and every
600 seconds, independently of the existing one-minute usage refresh. The request has a 15-second timeout,
bypasses the local HTTP cache, requests revalidation, and sends no cookies or account credentials.

An orange border requires `data.scheduled_reset.status == "scheduled"` and `reset_type == "regular"`.
Forecast probabilities, completed resets, and banked reset credits do not qualify. An unknown or elapsed
`scheduled_for` time does not override the feed's execution state, as specified in the
[API schema](https://codex-resets.com/api/openapi.json). A failed request clears the reminder until the next
successful check.

## Checks

- `make test` and `make check`: 23 tests in seven suites passed, including eight announcement scenarios and
  five HTTP scenarios in the parameterized tests.
- Local HTTP stubs verify request URL, method, timeout, cache policy, and absence of credentials or cookies.
- State transitions cover pending, completed, pending again, offline, and recovery.
- Startup polling and cancellation of the ten-minute wait are covered without real account access.
- The live public endpoint returned HTTP 200 with no pending announcement during validation; a completed
  reset alone correctly leaves the border inactive.
- The orange outline is drawn inside the original 80 × 22 pt card, using TRAE's `status-warning-default`
  color (`#D27E24`) at 1.5 pt. It does not change the percentage layout or colors.
- The release app was installed through the packaged installer. The installed version reports 1.2.0, its
  ad-hoc signature verifies, and its per-user LaunchAgent is running. The DMG checksum also verifies.

The rendering fixture below shows, from top to bottom: normal display, pending reset, Luna Reserve with a
pending reset, low quota with a pending reset, and the existing quota-reset animation with a pending reset.
These are simulated states, not an announcement that a reset is currently pending.

![Reset announcement rendering states](reset-announcement-states.png)
