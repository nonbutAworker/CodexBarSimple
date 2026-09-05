import Foundation
import Testing

@testable import CodexBarSimple

struct CodexUsageLiveTests {
    @Test
    func `reads usage from the signed in Codex CLI when explicitly enabled`() async throws {
        guard ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_LIVE_TESTS"] == "1" else {
            return
        }

        let snapshot = try await CodexUsageClient().fetch()
        let displayedUsage = try #require(snapshot.preferredDisplay)
        let remaining = displayedUsage.window.remainingPercent

        #expect((0...100).contains(remaining))
        #expect(displayedUsage.window.usedPercent.isFinite)

        let kind =
            switch displayedUsage.kind {
            case .session:
                "session"
            case .weekly:
                "weekly"
            case .lunaReserve:
                "luna-reserve"
            }
        print(
            "LIVE_CODEX_USAGE kind=\(kind) used=\(displayedUsage.window.usedPercent) "
                + "remaining=\(PercentageFormatter.string(remaining))")
    }
}
