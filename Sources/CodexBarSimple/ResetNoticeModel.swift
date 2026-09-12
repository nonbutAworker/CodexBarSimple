import Foundation
import Observation

struct CodexResetStatus: Decodable {
    let data: StatusData

    var isResetScheduled: Bool {
        self.data.scheduledReset?.status == "scheduled"
            && self.data.scheduledReset?.resetType == "regular"
    }

    struct StatusData: Decodable {
        let scheduledReset: ScheduledReset?

        private enum CodingKeys: String, CodingKey {
            case scheduledReset = "scheduled_reset"
        }
    }

    struct ScheduledReset: Decodable {
        let status: String
        let resetType: String
        let id: String

        private enum CodingKeys: String, CodingKey {
            case status
            case resetType = "reset_type"
            case id
        }
    }
}

@MainActor
@Observable
final class ResetNoticeModel {
    private(set) var isResetScheduled = false

    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private let refreshInterval: Duration
    private(set) var bellEventID = 0
    @ObservationIgnored private var lastAnnouncedResetID: String?

    init(
        session: URLSession = URLSession(configuration: .ephemeral),
        refreshInterval: Duration = .seconds(600)
    ) {
        self.session = session
        self.refreshInterval = refreshInterval
    }

    func runRefreshLoop() async {
        while !Task.isCancelled {
            await self.refresh()
            do {
                try await Task.sleep(for: self.refreshInterval)
            } catch {
                return
            }
        }
    }

    func refresh() async {
        let url = URL(string: "https://codex-resets.com/api/v1/status")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.httpShouldHandleCookies = false

        do {
            let (data, response) = try await self.session.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let status = try JSONDecoder().decode(CodexResetStatus.self, from: data)
            self.isResetScheduled = status.isResetScheduled
            if status.isResetScheduled, let id = status.data.scheduledReset?.id,
                id != self.lastAnnouncedResetID
            {
                self.lastAnnouncedResetID = id
                self.bellEventID += 1
            }
        } catch {
            // An unavailable feed cannot confirm that a reset is still pending.
            self.isResetScheduled = false
        }
    }
}
