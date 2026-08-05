import Foundation

/// Splits newline-delimited child-process output without retaining an unbounded partial line.
final class BoundedLineBuffer: @unchecked Sendable {
    struct AppendResult: Sendable {
        let lines: [Data]
        let didExceedLimit: Bool
    }

    private let lock = NSLock()
    private let maxBytes: Int
    private var buffer = Data()

    init(maxBytes: Int = 1 * 1024 * 1024) {
        self.maxBytes = max(0, maxBytes)
    }

    func appendAndDrainLines(_ chunk: Data) -> AppendResult {
        self.lock.lock()
        defer { self.lock.unlock() }

        var lines: [Data] = []
        var segmentStart = chunk.startIndex
        while let newline = chunk[segmentStart...].firstIndex(of: 0x0A) {
            let segment = chunk[segmentStart..<newline]
            guard segment.count <= self.maxBytes - self.buffer.count else {
                return AppendResult(lines: [], didExceedLimit: true)
            }
            self.buffer.append(segment)
            if !self.buffer.isEmpty {
                lines.append(self.buffer)
            }
            self.buffer.removeAll(keepingCapacity: true)
            segmentStart = chunk.index(after: newline)
        }

        let tail = chunk[segmentStart...]
        guard tail.count <= self.maxBytes - self.buffer.count else {
            return AppendResult(lines: [], didExceedLimit: true)
        }
        self.buffer.append(contentsOf: tail)
        return AppendResult(lines: lines, didExceedLimit: false)
    }
}
