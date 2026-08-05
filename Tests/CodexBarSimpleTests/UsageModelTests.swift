import Foundation
import Testing

@testable import CodexBarSimple

@MainActor
struct UsageModelTests {
    @Test
    func `keeps the last percentage after failure and clears the error after recovery`() async throws {
        let fixture = try CodexScriptFixture(mode: .successFailureRecovery)
        defer { fixture.remove() }

        let model = UsageModel(client: fixture.client)

        await model.refresh()
        #expect(model.displayText == "92%")
        #expect(model.remainingPercent == 92)

        await model.refresh()
        #expect(model.displayText == "92%")
        #expect(model.remainingPercent == 92)

        await model.refresh()
        #expect(model.displayText == "90%")
        #expect(model.remainingPercent == 90)
    }

    @Test
    func `shows an unavailable state when the first refresh fails`() async throws {
        let fixture = try CodexScriptFixture(mode: .alwaysFailure)
        defer { fixture.remove() }

        let model = UsageModel(client: fixture.client)
        await model.refresh()

        #expect(model.displayText == "--%")
        #expect(model.remainingPercent == nil)
    }

    @Test
    func `refresh loop fetches immediately and repeats until cancelled`() async throws {
        let fixture = try CodexScriptFixture(mode: .alwaysSuccess)
        defer { fixture.remove() }

        let model = UsageModel(
            client: fixture.client,
            refreshInterval: .milliseconds(50))
        let refreshTask = Task {
            await model.runRefreshLoop()
        }

        for _ in 0..<40 {
            if (try? fixture.requestCount()) ?? 0 >= 2 {
                break
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        refreshTask.cancel()
        await refreshTask.value

        #expect(try fixture.requestCount() >= 2)
        #expect(model.displayText == "92%")
    }

    @Test
    func `ignores a concurrent refresh while one is already running`() async throws {
        let fixture = try CodexScriptFixture(mode: .slowSuccess)
        defer { fixture.remove() }

        let model = UsageModel(client: fixture.client)
        let firstRefresh = Task {
            await model.refresh()
        }
        for _ in 0..<500 {
            if (try? fixture.requestCount()) == 1 {
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let secondRefresh = Task {
            await model.refresh()
        }

        await firstRefresh.value
        await secondRefresh.value

        #expect(try fixture.requestCount() == 1)
        #expect(model.displayText == "92%")
    }

    @Test
    func `announces a reset once when observed usage returns to one hundred percent`() async throws {
        let fixture = try CodexScriptFixture(mode: .usageThenReset)
        defer { fixture.remove() }

        let model = UsageModel(client: fixture.client)

        await model.refresh()
        #expect(model.displayText == "92%")
        #expect(model.resetEventID == 0)

        await model.refresh()
        #expect(model.displayText == "100%")
        #expect(model.resetEventID == 1)

        await model.refresh()
        #expect(model.resetEventID == 1)
        #expect(!UsageModel.detectedReset(from: nil, to: 100))
    }
}

private struct CodexScriptFixture {
    enum Mode {
        case alwaysSuccess
        case alwaysFailure
        case slowSuccess
        case successFailureRecovery
        case usageThenReset
    }

    let directory: URL
    let executable: URL
    let stateFile: URL

    init(mode: Mode) throws {
        self.directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbarsimple-model-\(UUID().uuidString)", isDirectory: true)
        self.executable = self.directory.appendingPathComponent("codex")
        self.stateFile = self.directory.appendingPathComponent("count")

        try FileManager.default.createDirectory(
            at: self.directory,
            withIntermediateDirectories: true)

        let responseCase =
            switch mode {
            case .alwaysSuccess:
                """
                      printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":8,"windowDurationMins":300}}}}'
                """
            case .alwaysFailure:
                """
                      printf '%s\\n' '{"id":2,"error":{"code":-32000,"message":"simulated failure"}}'
                """
            case .slowSuccess:
                """
                      sleep 0.2
                      printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":8,"windowDurationMins":300}}}}'
                """
            case .successFailureRecovery:
                """
                      case "$count" in
                        1)
                          printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":8,"windowDurationMins":300}}}}'
                          ;;
                        2)
                          printf '%s\\n' '{"id":2,"error":{"code":-32000,"message":"simulated failure"}}'
                          ;;
                        *)
                          printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":10,"windowDurationMins":300}}}}'
                          ;;
                      esac
                """
            case .usageThenReset:
                """
                      if [ "$count" -eq 1 ]; then
                        printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":8,"windowDurationMins":300}}}}'
                      else
                        printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":0,"windowDurationMins":300}}}}'
                      fi
                """
            }

        let script = """
            #!/bin/sh
            state_file="\(self.stateFile.path)"
            while IFS= read -r line; do
              case "$line" in
                *'"id":1'*)
                  printf '%s\\n' '{"id":1,"result":{}}'
                  ;;
                *'"method":"initialized"'*)
                  ;;
                *'"id":2'*)
                  count=0
                  if [ -f "$state_file" ]; then
                    count=$(cat "$state_file")
                  fi
                  count=$((count + 1))
                  printf '%s' "$count" >"$state_file"
            \(responseCase)
                  ;;
              esac
            done
            """
        try script.write(to: self.executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: self.executable.path)
    }

    var client: CodexUsageClient {
        CodexUsageClient(
            environment: [
                "CODEX_CLI_PATH": self.executable.path,
                "HOME": self.directory.path,
                "PATH": "/usr/bin:/bin",
            ],
            initializeTimeout: 5,
            requestTimeout: 5)
    }

    func requestCount() throws -> Int {
        let value = try String(contentsOf: self.stateFile, encoding: .utf8)
        return try #require(Int(value))
    }

    func remove() {
        try? FileManager.default.removeItem(at: self.directory)
    }
}
