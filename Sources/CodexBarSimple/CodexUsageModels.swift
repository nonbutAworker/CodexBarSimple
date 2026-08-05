import Foundation

struct CodexRateWindow: Equatable, Sendable {
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: Date?

    var remainingPercent: Double {
        min(100, max(0, 100 - self.usedPercent))
    }
}

enum CodexWindowKind: Equatable, Sendable {
    case session
    case weekly

    var title: String {
        switch self {
        case .session:
            "Codex 5 小时窗口"
        case .weekly:
            "Codex 周窗口"
        }
    }
}

struct CodexDisplayedUsage: Equatable, Sendable {
    let kind: CodexWindowKind
    let window: CodexRateWindow
}

struct CodexUsageSnapshot: Equatable, Sendable {
    let session: CodexRateWindow?
    let weekly: CodexRateWindow?

    var preferredDisplay: CodexDisplayedUsage? {
        if let session {
            return CodexDisplayedUsage(kind: .session, window: session)
        }
        if let weekly {
            return CodexDisplayedUsage(kind: .weekly, window: weekly)
        }
        return nil
    }

    static func normalized(
        primary: CodexRateWindow?,
        secondary: CodexRateWindow?
    ) -> CodexUsageSnapshot {
        switch (primary, secondary) {
        case (.some(let primaryWindow), .some(let secondaryWindow)):
            switch (self.role(for: primaryWindow), self.role(for: secondaryWindow)) {
            case (.session, .weekly), (.session, .unknown), (.unknown, .weekly):
                return CodexUsageSnapshot(session: primaryWindow, weekly: secondaryWindow)
            case (.weekly, .session), (.weekly, .unknown):
                return CodexUsageSnapshot(session: secondaryWindow, weekly: primaryWindow)
            default:
                return CodexUsageSnapshot(session: primaryWindow, weekly: secondaryWindow)
            }

        case (.some(let primaryWindow), .none):
            if self.role(for: primaryWindow) == .weekly {
                return CodexUsageSnapshot(session: nil, weekly: primaryWindow)
            }
            return CodexUsageSnapshot(session: primaryWindow, weekly: nil)

        case (.none, .some(let secondaryWindow)):
            if self.role(for: secondaryWindow) == .weekly {
                return CodexUsageSnapshot(session: nil, weekly: secondaryWindow)
            }
            return CodexUsageSnapshot(session: secondaryWindow, weekly: nil)

        case (.none, .none):
            return CodexUsageSnapshot(session: nil, weekly: nil)
        }
    }

    private enum WindowRole {
        case session
        case weekly
        case unknown
    }

    private static func role(for window: CodexRateWindow) -> WindowRole {
        switch window.windowMinutes {
        case 5 * 60:
            .session
        case 7 * 24 * 60:
            .weekly
        default:
            .unknown
        }
    }
}

enum PercentageFormatter {
    static func string(_ percent: Double) -> String {
        guard percent.isFinite else { return "--%" }
        let clamped = min(100, max(0, percent))
        if clamped > 0, clamped < 1 {
            return "<1%"
        }
        return String(format: "%.0f%%", clamped)
    }
}
