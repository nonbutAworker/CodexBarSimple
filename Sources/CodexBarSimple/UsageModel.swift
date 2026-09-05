import Foundation
import Observation

@MainActor
@Observable
final class UsageModel {
    private(set) var displayText = "--%"
    private(set) var remainingPercent: Double?
    private(set) var displayKind: CodexWindowKind?
    private(set) var resetEventID = 0

    var accessibilityLabel: String {
        self.displayKind?.isLunaReserve == true ? "Luna Reserve 剩余用量" : "Codex 剩余用量"
    }

    @ObservationIgnored private let client: CodexUsageClient
    @ObservationIgnored private let refreshInterval: Duration
    @ObservationIgnored private var isRefreshing = false

    init(
        client: CodexUsageClient = CodexUsageClient(),
        refreshInterval: Duration = .seconds(60)
    ) {
        self.client = client
        self.refreshInterval = refreshInterval
    }

    func runRefreshLoop() async {
        await self.refresh()

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: self.refreshInterval)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await self.refresh()
        }
    }

    func refresh() async {
        guard !self.isRefreshing else { return }
        self.isRefreshing = true
        defer { self.isRefreshing = false }

        do {
            let snapshot = try await self.client.fetch()
            guard let displayedUsage = snapshot.preferredDisplay else {
                throw CodexUsageClientError.noRateLimits
            }

            let text = PercentageFormatter.string(displayedUsage.window.remainingPercent)
            let didReset = Self.detectedReset(
                from: self.remainingPercent,
                previousKind: self.displayKind,
                to: displayedUsage.window.remainingPercent,
                currentKind: displayedUsage.kind)
            self.displayText = text
            self.remainingPercent = displayedUsage.window.remainingPercent
            self.displayKind = displayedUsage.kind
            if didReset {
                self.resetEventID += 1
            }
        } catch {
            if self.remainingPercent == nil {
                self.displayText = "--%"
            }
        }
    }

    static func detectedReset(from previous: Double?, to current: Double) -> Bool {
        guard let previous else { return false }
        return PercentageFormatter.string(previous) != "100%"
            && PercentageFormatter.string(current) == "100%"
    }

    static func detectedReset(
        from previous: Double?,
        previousKind: CodexWindowKind?,
        to current: Double,
        currentKind: CodexWindowKind
    ) -> Bool {
        guard !currentKind.isLunaReserve else { return false }
        _ = previousKind
        return Self.detectedReset(from: previous, to: current)
    }
}
