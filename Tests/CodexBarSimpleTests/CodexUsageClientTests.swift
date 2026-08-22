import Foundation
import Testing

@testable import CodexBarSimple

@Suite
struct CodexUsageClientTests {
    @Test
    func `fetches usage through a read only Codex app server process`() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbarsimple-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let stubURL = temporaryDirectory.appendingPathComponent("codex")
        let argumentsURL = temporaryDirectory.appendingPathComponent("arguments")
        let script = """
            #!/bin/sh
            printf '%s\\n' "$@" > "$HOME/arguments"
            while IFS= read -r line; do
              case "$line" in
                *'"id":1'*)
                  printf '%s\\n' '{"id":1,"result":{}}'
                  ;;
                *'"method":"initialized"'*)
                  ;;
                *'"id":2'*)
                  printf '%s\\n' '{"id":2,"result":{"rateLimits":{"primary":{"usedPercent":8,"windowDurationMins":300},"secondary":{"usedPercent":43,"windowDurationMins":10080}}}}'
                  ;;
              esac
            done
            """
        try script.write(to: stubURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stubURL.path)

        let client = CodexUsageClient(
            environment: [
                "CODEX_CLI_PATH": stubURL.path,
                "HOME": temporaryDirectory.path,
                "PATH": "/usr/bin:/bin",
            ],
            initializeTimeout: 1,
            requestTimeout: 1)

        let snapshot = try await client.fetch()

        #expect(snapshot.preferredDisplay?.kind == .session)
        #expect(snapshot.preferredDisplay?.window.remainingPercent == 92)
        #expect(
            try String(contentsOf: argumentsURL, encoding: .utf8)
                .split(whereSeparator: \.isNewline)
                .map(String.init) == ["-s", "read-only", "-a", "never", "app-server"])
    }
}
