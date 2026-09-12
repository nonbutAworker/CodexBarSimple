import Foundation

enum CodexRPCError: Error {
    case launchFailed
    case requestFailed(String)
    case malformedResponse
    case timeout(method: String)
}

/// The instance is confined to one detached fetch task.
final class CodexRPCClient: @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let stdoutLineStream: AsyncStream<Data>
    private let stdoutLineContinuation: AsyncStream<Data>.Continuation
    private let initializeTimeout: TimeInterval
    private let requestTimeout: TimeInterval
    private var nextID = 1

    init(
        resolution: CodexExecutableResolution,
        initializeTimeout: TimeInterval,
        requestTimeout: TimeInterval
    ) throws {
        self.initializeTimeout = initializeTimeout
        self.requestTimeout = requestTimeout

        var capturedContinuation: AsyncStream<Data>.Continuation!
        self.stdoutLineStream = AsyncStream<Data> { continuation in
            capturedContinuation = continuation
        }
        self.stdoutLineContinuation = capturedContinuation

        self.process.environment = resolution.environment
        self.process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        self.process.arguments = [
            resolution.executable,
            "-s",
            "read-only",
            "-a",
            "never",
            "app-server",
        ]
        self.process.standardInput = self.stdinPipe
        self.process.standardOutput = self.stdoutPipe
        self.process.standardError = self.stderrPipe

        do {
            try self.process.run()
        } catch {
            throw CodexRPCError.launchFailed
        }

        let lineBuffer = BoundedLineBuffer()
        let stdoutContinuation = self.stdoutLineContinuation
        let process = self.process
        self.stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                stdoutContinuation.finish()
                return
            }

            let result = lineBuffer.appendAndDrainLines(data)
            if result.didExceedLimit {
                handle.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
                stdoutContinuation.finish()
                return
            }

            for line in result.lines {
                stdoutContinuation.yield(line)
            }
        }

        self.stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty {
                handle.readabilityHandler = nil
            }
        }
    }

    deinit {
        self.shutdown()
    }

    func initialize() async throws {
        _ = try await self.request(
            method: "initialize",
            params: [
                "clientInfo": [
                    "name": "codexbarsimple",
                    "version": "1.4.1",
                ]
            ],
            timeout: self.initializeTimeout)
        try self.sendNotification(method: "initialized")
    }

    func fetchRateLimitsResult() async throws -> Data {
        let message = try await self.request(method: "account/rateLimits/read")
        guard let result = message["result"],
            JSONSerialization.isValidJSONObject(result)
        else {
            throw CodexRPCError.malformedResponse
        }
        return try JSONSerialization.data(withJSONObject: result)
    }

    func shutdown() {
        self.stdoutPipe.fileHandleForReading.readabilityHandler = nil
        self.stderrPipe.fileHandleForReading.readabilityHandler = nil
        try? self.stdinPipe.fileHandleForWriting.close()
        if self.process.isRunning {
            self.process.terminate()
        }
        self.stdoutLineContinuation.finish()
    }

    private struct SendableJSONMessage: @unchecked Sendable {
        let value: [String: Any]
    }

    private func request(
        method: String,
        params: [String: Any]? = nil,
        timeout: TimeInterval? = nil
    ) async throws -> [String: Any] {
        let id = self.nextID
        self.nextID += 1
        try self.sendRequest(id: id, method: method, params: params)

        let wrapped = try await self.withTimeout(
            seconds: timeout ?? self.requestTimeout,
            method: method
        ) {
            while true {
                let message = try await self.readNextMessage()

                if message["id"] == nil, message["method"] is String {
                    continue
                }

                guard self.jsonID(message["id"]) == id else {
                    continue
                }

                if let error = message["error"] as? [String: Any],
                    let messageText = error["message"] as? String
                {
                    throw CodexRPCError.requestFailed(messageText)
                }

                return SendableJSONMessage(value: message)
            }
        }
        return wrapped.value
    }

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        method: String,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask { [weak self] in
                try await Task.sleep(for: .seconds(seconds))
                self?.terminateAfterTimeout()
                throw CodexRPCError.timeout(method: method)
            }

            do {
                guard let result = try await group.next() else {
                    throw CodexRPCError.timeout(method: method)
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                throw error
            }
        }
    }

    private func terminateAfterTimeout() {
        if self.process.isRunning {
            self.process.terminate()
        }
    }

    private func sendNotification(method: String) throws {
        try self.sendPayload([
            "method": method,
            "params": [:],
        ])
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        try self.sendPayload([
            "id": id,
            "method": method,
            "params": params ?? [:],
        ])
    }

    private func sendPayload(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        self.stdinPipe.fileHandleForWriting.write(data)
        self.stdinPipe.fileHandleForWriting.write(Data([0x0A]))
    }

    private func readNextMessage() async throws -> [String: Any] {
        for await line in self.stdoutLineStream {
            guard !line.isEmpty else { continue }
            if let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] {
                return message
            }
        }
        throw CodexRPCError.malformedResponse
    }

    private func jsonID(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            int
        case let number as NSNumber:
            number.intValue
        default:
            nil
        }
    }
}
