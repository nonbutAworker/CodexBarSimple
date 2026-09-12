import Foundation
import Testing

@testable import CodexBarSimple

@MainActor
struct ResetNoticeTests {
    @Test(arguments: [
        (
            #"{"scheduled_reset":{"id":"reset-1","status":"scheduled","reset_type":"regular","scheduled_for":null}}"#,
            true
        ),
        (
            #"{"scheduled_reset":{"id":"reset-1","status":"scheduled","reset_type":"regular","scheduled_for":"2020-01-01T00:00:00Z"}}"#,
            true
        ),
        (#"{"scheduled_reset":{"id":"reset-1","status":"scheduled","reset_type":"banked"}}"#, false),
        (#"{"scheduled_reset":{"id":"reset-1","status":"completed","reset_type":"regular"}}"#, false),
        (#"{"scheduled_reset":{"id":"reset-1","status":"scheduled","reset_type":"unknown"}}"#, false),
        (#"{"scheduled_reset":null,"active_watch":{"level":"strong","reset_chance_percent":100}}"#, false),
        (#"{"scheduled_reset":null,"latest_reset":{"reset_type":"regular"}}"#, false),
        (#"{"scheduled_reset":null}"#, false),
    ])
    func `only explicit pending regular resets trigger a reminder`(_ payload: String, _ expected: Bool) throws {
        let data = Data("{\"data\":\(payload)}".utf8)
        let status = try JSONDecoder().decode(CodexResetStatus.self, from: data)
        #expect(status.isResetScheduled == expected)
    }

    @Test(arguments: ["scheduled", "clear", "unavailable", "malformed", "offline"])
    func `checks the public feed without cached data or account credentials`(_ scenario: String) async {
        let session = Self.session(scenario: scenario)
        defer { session.invalidateAndCancel() }
        let model = ResetNoticeModel(session: session)

        await model.refresh()

        #expect(model.isResetScheduled == (scenario == "scheduled"))
        #expect(model.scheduledResetID == (scenario == "scheduled" ? "reset-1" : nil))
    }

    @Test
    func `clears completed or unverifiable reminders and recovers on the next check`() async {
        let session = Self.session(scenario: "scheduled,clear,scheduled,offline,scheduled")
        defer { session.invalidateAndCancel() }
        let model = ResetNoticeModel(session: session)
        for expected in [true, false, true, false, true] {
            await model.refresh()
            #expect(model.isResetScheduled == expected)
        }
    }

    @Test
    func `rings once per new announcement despite repeated checks and temporary failures`() async {
        let session = Self.session(
            scenario: "scheduled,scheduled,offline,scheduled,clear,scheduled,scheduled-new,scheduled-new")
        defer { session.invalidateAndCancel() }
        let model = ResetNoticeModel(session: session)
        #expect(model.bellEventID == 0)

        for expectedEventID in [1, 1, 1, 1, 1, 1, 2, 2] {
            await model.refresh()
            #expect(model.bellEventID == expectedEventID)
        }
    }

    @Test
    func `bell swings both ways for one minute then rests`() {
        #expect(ResetBellMotion.duration == 60)
        #expect(abs(ResetBellMotion.rotation(at: 0.2) - 18) < 0.001)
        #expect(abs(ResetBellMotion.rotation(at: 0.6) + 18) < 0.001)
        #expect(abs(ResetBellMotion.rotation(at: 59.8) + 18) < 0.001)
        #expect(abs(ResetBellMotion.rotation(at: 59.9)) < 18)
        for elapsed: TimeInterval in [-1, 0, 60, 61, 600] {
            #expect(ResetBellMotion.rotation(at: elapsed) == 0)
        }
    }

    @Test
    func `checks immediately at launch and cancellation interrupts the ten minute wait`() async throws {
        let session = Self.session(scenario: "scheduled")
        defer { session.invalidateAndCancel() }
        let model = ResetNoticeModel(session: session)
        let task = Task {
            await model.runRefreshLoop()
        }
        defer { task.cancel() }

        for _ in 0..<100 {
            if model.isResetScheduled { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(model.isResetScheduled)
        task.cancel()
        await task.value
    }

    private static func session(scenario: String) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ResetStatusURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            "X-Reset-Test-Scenario": scenario,
            "X-Reset-Test-ID": UUID().uuidString,
        ]
        return URLSession(configuration: configuration)
    }
}

private final class ResetStatusURLProtocol: URLProtocol, @unchecked Sendable {
    private static let requestCounts = ResetRequestCounts()

    override class func canInit(with _: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard
            self.request.url?.absoluteString == "https://codex-resets.com/api/v1/status",
            self.request.httpMethod == "GET",
            self.request.httpBody == nil,
            self.request.value(forHTTPHeaderField: "Authorization") == nil,
            self.request.value(forHTTPHeaderField: "Cookie") == nil,
            self.request.value(forHTTPHeaderField: "Accept") == "application/json",
            self.request.value(forHTTPHeaderField: "Cache-Control") == "no-cache",
            self.request.cachePolicy == .reloadIgnoringLocalCacheData,
            self.request.timeoutInterval == 15,
            !self.request.httpShouldHandleCookies
        else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let scenarios = (self.request.value(forHTTPHeaderField: "X-Reset-Test-Scenario") ?? "scheduled")
            .split(separator: ",")
        let index = Self.requestCounts.nextIndex(for: self.request.value(forHTTPHeaderField: "X-Reset-Test-ID")!)
        let scenario = scenarios[min(index, scenarios.count - 1)]
        if scenario == "offline" {
            self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let body: String
        switch scenario {
        case "clear":
            body = #"{"data":{"scheduled_reset":null}}"#
        case "malformed":
            body = "invalid JSON"
        case "scheduled-new":
            body = #"{"data":{"scheduled_reset":{"id":"reset-2","status":"scheduled","reset_type":"regular"}}}"#
        default:
            body = #"{"data":{"scheduled_reset":{"id":"reset-1","status":"scheduled","reset_type":"regular"}}}"#
        }
        let response = HTTPURLResponse(
            url: self.request.url!,
            statusCode: scenario == "unavailable" ? 503 : 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json", "Cache-Control": "public, max-age=14400"]
        )!
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        self.client?.urlProtocol(self, didLoad: Data(body.utf8))
        self.client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class ResetRequestCounts: @unchecked Sendable {
    private let lock = NSLock()
    private var counts: [String: Int] = [:]

    func nextIndex(for id: String) -> Int {
        self.lock.withLock {
            let index = self.counts[id, default: 0]
            self.counts[id] = index + 1
            return index
        }
    }
}
