import Foundation
import Testing

@testable import CodexBarSimple

@Suite
struct CodexUsageParserTests {
    @Test
    func `decodes the five hour window and displays remaining percentage`() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "primary": {
                  "usedPercent": 8,
                  "windowDurationMins": 300,
                  "resetsAt": 1782864000
                },
                "secondary": {
                  "usedPercent": 43,
                  "windowDurationMins": 10080,
                  "resetsAt": 1783000000
                }
              }
            }
            """.utf8)

        let snapshot = try CodexUsageParser.decodeRPCResult(data)

        #expect(snapshot.session?.usedPercent == 8)
        #expect(snapshot.weekly?.usedPercent == 43)
        #expect(snapshot.preferredDisplay?.kind == .session)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 92)
        #expect(
            PercentageFormatter.string(snapshot.preferredDisplay?.window.remainingPercent ?? -1) == "92%")
    }

    @Test
    func `uses Luna Reserve after the normal quota is exhausted`() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "primary": {
                  "usedPercent": 100,
                  "windowDurationMins": 10080
                }
              },
              "rateLimitsByLimitId": {
                "base_model_inference": {
                  "limitId": "base_model_inference",
                  "limitName": "gpt-reserve",
                  "primary": {
                    "usedPercent": 2,
                    "windowDurationMins": 10080,
                    "resetsAt": 1789182314
                  }
                }
              }
            }
            """.utf8)

        let snapshot = try CodexUsageParser.decodeRPCResult(data)

        #expect(snapshot.weekly?.remainingPercent == 0)
        #expect(snapshot.lunaReserve?.usedPercent == 2)
        #expect(snapshot.preferredDisplay?.kind == .lunaReserve)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 98)
    }

    @Test
    func `keeps the normal quota ahead of Luna Reserve`() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "primary": {
                  "usedPercent": 8,
                  "windowDurationMins": 300
                }
              },
              "rateLimitsByLimitId": {
                "base_model_inference": {
                  "limitName": "gpt-reserve",
                  "primary": {
                    "usedPercent": 2,
                    "windowDurationMins": 10080
                  }
                }
              }
            }
            """.utf8)

        let snapshot = try CodexUsageParser.decodeRPCResult(data)

        #expect(snapshot.preferredDisplay?.kind == .session)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 92)
    }

    @Test
    func `normalizes swapped session and weekly windows`() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "primary": {
                  "usedPercent": 55,
                  "windowDurationMins": 10080
                },
                "secondary": {
                  "usedPercent": 20,
                  "windowDurationMins": 300
                }
              }
            }
            """.utf8)

        let snapshot = try CodexUsageParser.decodeRPCResult(data)

        #expect(snapshot.session?.usedPercent == 20)
        #expect(snapshot.weekly?.usedPercent == 55)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 80)
    }

    @Test
    func `falls back to the weekly window when the session window is absent`() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "secondary": {
                  "usedPercent": 25,
                  "windowDurationMins": 10080
                }
              }
            }
            """.utf8)

        let snapshot = try CodexUsageParser.decodeRPCResult(data)

        #expect(snapshot.session == nil)
        #expect(snapshot.preferredDisplay?.kind == .weekly)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 75)
    }

    @Test
    func `recovers usage from a backend body embedded in an RPC error`() throws {
        let message = """
            failed to fetch Codex rate limits; body={
              "plan_type": "future-plan",
              "rate_limit": {
                "primary_window": {
                  "used_percent": 4,
                  "limit_window_seconds": 18000,
                  "reset_at": 1782864000
                },
                "secondary_window": {
                  "used_percent": 19,
                  "limit_window_seconds": 604800,
                  "reset_at": 1783000000
                }
              }
            }
            """

        let snapshot = try #require(CodexUsageParser.recoverFromRPCErrorMessage(message))

        #expect(snapshot.session?.usedPercent == 4)
        #expect(snapshot.weekly?.usedPercent == 19)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 96)
    }

    @Test
    func `formats percentages like CodexBar`() {
        #expect(PercentageFormatter.string(-1) == "0%")
        #expect(PercentageFormatter.string(0.1) == "<1%")
        #expect(PercentageFormatter.string(0.96) == "<1%")
        #expect(PercentageFormatter.string(1) == "1%")
        #expect(PercentageFormatter.string(92.239) == "92%")
        #expect(PercentageFormatter.string(101) == "100%")
    }
}
