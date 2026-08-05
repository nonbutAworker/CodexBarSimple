import Foundation

struct CodexExecutableResolution: Sendable {
    let executable: String
    let environment: [String: String]
}

enum CodexExecutableLocator {
    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> CodexExecutableResolution? {
        let home = environment["HOME"] ?? NSHomeDirectory()
        let pathEntries = self.pathEntries(environment["PATH"])
        var candidates: [String] = []

        if let override = environment["CODEX_CLI_PATH"], !override.isEmpty {
            candidates.append(override)
        }

        candidates.append(
            contentsOf: pathEntries.map {
                URL(fileURLWithPath: $0).appendingPathComponent("codex").path
            })

        candidates.append(contentsOf: [
            "\(home)/.local/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.asdf/shims/codex",
            "\(home)/.nix-profile/bin/codex",
            "\(home)/.bun/bin/codex",
            "\(home)/Library/pnpm/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
        ])

        candidates.append(
            contentsOf: self.versionManagedCandidates(home: home, fileManager: fileManager))
        candidates.append(contentsOf: [
            "\(home)/Applications/ChatGPT.app/Contents/Resources/codex",
            "\(home)/Applications/Codex.app/Contents/Resources/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
        ])

        let executableCandidates = self.unique(candidates).filter(fileManager.isExecutableFile(atPath:))
        guard let executable = executableCandidates.first else {
            return nil
        }

        var launchEnvironment = environment
        let candidateDirectories = executableCandidates.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().path
        }
        launchEnvironment["PATH"] = self.unique(
            [URL(fileURLWithPath: executable).deletingLastPathComponent().path] + pathEntries
                + candidateDirectories + ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        )
        .joined(separator: ":")

        return CodexExecutableResolution(
            executable: executable,
            environment: launchEnvironment)
    }

    private static func versionManagedCandidates(
        home: String,
        fileManager: FileManager
    ) -> [String] {
        var candidates: [String] = []
        let rootsAndSuffixes = [
            ("\(home)/.nvm/versions/node", "bin/codex"),
            ("\(home)/.local/share/fnm/node-versions", "installation/bin/codex"),
        ]

        for (root, suffix) in rootsAndSuffixes {
            guard let versions = try? fileManager.contentsOfDirectory(atPath: root) else {
                continue
            }
            for version in versions.sorted(by: >) {
                candidates.append(
                    URL(fileURLWithPath: root)
                        .appendingPathComponent(version)
                        .appendingPathComponent(suffix)
                        .path)
            }
        }

        return candidates
    }

    private static func pathEntries(_ path: String?) -> [String] {
        path?
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty } ?? []
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
