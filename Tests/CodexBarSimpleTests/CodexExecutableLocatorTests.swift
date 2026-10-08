import Foundation
import Testing

@testable import CodexBarSimple

struct CodexExecutableLocatorTests {
    @Test(arguments: [
        "/Users/example/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "/Users/example/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "/Applications/Codex.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        "/Users/example/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Users/example/Applications/Codex.app/Contents/Resources/codex",
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex",
    ])
    func `finds the desktop CLI with only the background service PATH`(_ path: String) throws {
        let environment = ["HOME": "/Users/example", "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        let resolution = try #require(
            CodexExecutableLocator.resolve(
                environment: environment, fileManager: ExecutableFileManager(paths: [path])))

        #expect(resolution.executable == path)
        #expect(resolution.environment["HOME"] == environment["HOME"])
        #expect(
            resolution.environment["PATH"]?.split(separator: ":").first
                == URL(fileURLWithPath: path)
                .deletingLastPathComponent().path[...])
    }

    @Test(arguments: [true, false])
    func `keeps an explicit override and PATH CLI ahead of desktop fallback`(_ hasOverride: Bool) throws {
        let paths: Set<String> = [
            "/custom/codex", "/preferred/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex",
        ]
        var environment = ["HOME": "/Users/example", "PATH": "/preferred/bin:/usr/bin:/bin"]
        if hasOverride { environment["CODEX_CLI_PATH"] = "/custom/codex" }
        let resolution = try #require(
            CodexExecutableLocator.resolve(
                environment: environment, fileManager: ExecutableFileManager(paths: paths)))

        #expect(resolution.executable == (hasOverride ? "/custom/codex" : "/preferred/bin/codex"))
    }
}

private final class ExecutableFileManager: FileManager, @unchecked Sendable {
    private let executablePaths: Set<String>

    init(paths: Set<String>) {
        self.executablePaths = paths
        super.init()
    }

    override func isExecutableFile(atPath path: String) -> Bool {
        self.executablePaths.contains(path)
    }

    override func contentsOfDirectory(atPath _: String) throws -> [String] { [] }
}
