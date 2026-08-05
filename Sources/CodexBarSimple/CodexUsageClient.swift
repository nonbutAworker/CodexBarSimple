import Foundation

enum CodexUsageClientError: LocalizedError, Sendable {
    case cliNotFound
    case launchFailed
    case timedOut
    case requestFailed
    case invalidResponse
    case noRateLimits

    var errorDescription: String? {
        switch self {
        case .cliNotFound:
            "未找到 Codex CLI。请先安装并登录 Codex。"
        case .launchFailed:
            "Codex CLI 无法启动。请先在终端运行一次 codex。"
        case .timedOut:
            "读取 Codex 用量超时。"
        case .requestFailed:
            "Codex 没有返回可用的用量数据。"
        case .invalidResponse:
            "Codex 返回了无法识别的用量数据。"
        case .noRateLimits:
            "当前 Codex 账号没有可显示的用量窗口。"
        }
    }
}

struct CodexUsageClient: Sendable {
    private let environment: [String: String]
    private let initializeTimeout: TimeInterval
    private let requestTimeout: TimeInterval

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        initializeTimeout: TimeInterval = 8,
        requestTimeout: TimeInterval = 5
    ) {
        self.environment = environment
        self.initializeTimeout = initializeTimeout
        self.requestTimeout = requestTimeout
    }

    func fetch() async throws -> CodexUsageSnapshot {
        let environment = self.environment
        let initializeTimeout = self.initializeTimeout
        let requestTimeout = self.requestTimeout

        return try await Task.detached(priority: .utility) {
            try await Self.fetch(
                environment: environment,
                initializeTimeout: initializeTimeout,
                requestTimeout: requestTimeout)
        }.value
    }

    private static func fetch(
        environment: [String: String],
        initializeTimeout: TimeInterval,
        requestTimeout: TimeInterval
    ) async throws -> CodexUsageSnapshot {
        guard let resolution = CodexExecutableLocator.resolve(environment: environment) else {
            throw CodexUsageClientError.cliNotFound
        }

        let rpc: CodexRPCClient
        do {
            rpc = try CodexRPCClient(
                resolution: resolution,
                initializeTimeout: initializeTimeout,
                requestTimeout: requestTimeout)
        } catch {
            throw CodexUsageClientError.launchFailed
        }
        defer { rpc.shutdown() }

        do {
            try await rpc.initialize()
        } catch {
            throw self.mapRPCError(error)
        }

        let data: Data
        do {
            data = try await rpc.fetchRateLimitsResult()
        } catch let CodexRPCError.requestFailed(message) {
            if let recovered = CodexUsageParser.recoverFromRPCErrorMessage(message) {
                return recovered
            }
            throw CodexUsageClientError.requestFailed
        } catch {
            throw self.mapRPCError(error)
        }

        do {
            return try CodexUsageParser.decodeRPCResult(data)
        } catch CodexUsageParserError.noRateLimits {
            throw CodexUsageClientError.noRateLimits
        } catch {
            throw CodexUsageClientError.invalidResponse
        }
    }

    private static func mapRPCError(_ error: Error) -> CodexUsageClientError {
        switch error {
        case CodexRPCError.launchFailed:
            .launchFailed
        case CodexRPCError.timeout:
            .timedOut
        case CodexRPCError.requestFailed:
            .requestFailed
        case CodexRPCError.malformedResponse:
            .invalidResponse
        default:
            .requestFailed
        }
    }
}
