import Foundation

enum CodexUsageParserError: Error {
    case invalidResponse
    case noRateLimits
}

enum CodexUsageParser {
    static func decodeRPCResult(_ data: Data) throws -> CodexUsageSnapshot {
        let response: RPCRateLimitsResponse
        do {
            response = try JSONDecoder().decode(RPCRateLimitsResponse.self, from: data)
        } catch {
            throw CodexUsageParserError.invalidResponse
        }

        let snapshot = CodexUsageSnapshot.normalized(
            primary: self.makeWindow(response.rateLimits.primary),
            secondary: self.makeWindow(response.rateLimits.secondary))
        guard snapshot.preferredDisplay != nil else {
            throw CodexUsageParserError.noRateLimits
        }
        return snapshot
    }

    static func recoverFromRPCErrorMessage(_ message: String) -> CodexUsageSnapshot? {
        guard let json = self.extractJSONObject(after: "body=", in: message),
            let data = json.data(using: .utf8),
            let response = try? JSONDecoder().decode(BackendUsageResponse.self, from: data)
        else {
            return nil
        }

        let snapshot = CodexUsageSnapshot.normalized(
            primary: self.makeWindow(response.rateLimit?.primaryWindow),
            secondary: self.makeWindow(response.rateLimit?.secondaryWindow))
        return snapshot.preferredDisplay == nil ? nil : snapshot
    }

    private static func makeWindow(_ window: RPCWindow?) -> CodexRateWindow? {
        guard let window, window.usedPercent.isFinite else { return nil }
        return CodexRateWindow(
            usedPercent: window.usedPercent,
            windowMinutes: window.windowDurationMins,
            resetsAt: window.resetsAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            })
    }

    private static func makeWindow(_ window: BackendWindow?) -> CodexRateWindow? {
        guard let window, window.usedPercent.isFinite else { return nil }
        return CodexRateWindow(
            usedPercent: window.usedPercent,
            windowMinutes: window.limitWindowSeconds.map { $0 / 60 },
            resetsAt: window.resetAt.map {
                Date(timeIntervalSince1970: TimeInterval($0))
            })
    }

    private static func extractJSONObject(after marker: String, in text: String) -> String? {
        guard let markerRange = text.range(of: marker) else { return nil }
        let suffix = text[markerRange.upperBound...]
        guard let start = suffix.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        for index in suffix[start...].indices {
            let character = suffix[index]

            if inString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            switch character {
            case "\"":
                inString = true
            case "{":
                depth += 1
            case "}":
                depth -= 1
                if depth == 0 {
                    return String(suffix[start...index])
                }
            default:
                break
            }
        }

        return nil
    }
}

private struct RPCRateLimitsResponse: Decodable {
    let rateLimits: RPCRateLimitSnapshot

    private enum CodingKeys: String, CodingKey {
        case rateLimits
        case rateLimitsSnake = "rate_limits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(RPCRateLimitSnapshot.self, forKey: .rateLimits) {
            self.rateLimits = value
        } else {
            self.rateLimits = try container.decode(RPCRateLimitSnapshot.self, forKey: .rateLimitsSnake)
        }
    }
}

private struct RPCRateLimitSnapshot: Decodable {
    let primary: RPCWindow?
    let secondary: RPCWindow?

    private enum CodingKeys: String, CodingKey {
        case primary
        case secondary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primary = Self.decodeWindow(container, forKey: .primary)
        self.secondary = Self.decodeWindow(container, forKey: .secondary)
    }

    private static func decodeWindow(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> RPCWindow? {
        guard container.contains(key) else { return nil }
        return try? container.decode(RPCWindow.self, forKey: key)
    }
}

private struct RPCWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int?

    private enum CodingKeys: String, CodingKey {
        case usedPercent
        case usedPercentSnake = "used_percent"
        case windowDurationMins
        case windowDurationMinsSnake = "window_duration_mins"
        case resetsAt
        case resetsAtSnake = "resets_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(Double.self, forKey: .usedPercent) {
            self.usedPercent = value
        } else {
            self.usedPercent = try container.decode(Double.self, forKey: .usedPercentSnake)
        }
        self.windowDurationMins =
            (try? container.decodeIfPresent(Int.self, forKey: .windowDurationMins))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .windowDurationMinsSnake))
        self.resetsAt =
            (try? container.decodeIfPresent(Int.self, forKey: .resetsAt))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .resetsAtSnake))
    }
}

private struct BackendUsageResponse: Decodable {
    let rateLimit: BackendRateLimit?

    private enum CodingKeys: String, CodingKey {
        case rateLimit = "rate_limit"
        case rateLimitCamel = "rateLimit"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.rateLimit =
            (try? container.decodeIfPresent(BackendRateLimit.self, forKey: .rateLimit))
            ?? (try? container.decodeIfPresent(BackendRateLimit.self, forKey: .rateLimitCamel))
    }
}

private struct BackendRateLimit: Decodable {
    let primaryWindow: BackendWindow?
    let secondaryWindow: BackendWindow?

    private enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case primaryWindowCamel = "primaryWindow"
        case secondaryWindow = "secondary_window"
        case secondaryWindowCamel = "secondaryWindow"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.primaryWindow =
            Self.decodeWindow(container, primaryKey: .primaryWindow, fallbackKey: .primaryWindowCamel)
        self.secondaryWindow =
            Self.decodeWindow(container, primaryKey: .secondaryWindow, fallbackKey: .secondaryWindowCamel)
    }

    private static func decodeWindow(
        _ container: KeyedDecodingContainer<CodingKeys>,
        primaryKey: CodingKeys,
        fallbackKey: CodingKeys
    ) -> BackendWindow? {
        if container.contains(primaryKey) {
            return try? container.decode(BackendWindow.self, forKey: primaryKey)
        }
        if container.contains(fallbackKey) {
            return try? container.decode(BackendWindow.self, forKey: fallbackKey)
        }
        return nil
    }
}

private struct BackendWindow: Decodable {
    let usedPercent: Double
    let limitWindowSeconds: Int?
    let resetAt: Int?

    private enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case usedPercentCamel = "usedPercent"
        case limitWindowSeconds = "limit_window_seconds"
        case limitWindowSecondsCamel = "limitWindowSeconds"
        case resetAt = "reset_at"
        case resetAtCamel = "resetAt"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try container.decodeIfPresent(Double.self, forKey: .usedPercent) {
            self.usedPercent = value
        } else {
            self.usedPercent = try container.decode(Double.self, forKey: .usedPercentCamel)
        }
        self.limitWindowSeconds =
            (try? container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .limitWindowSecondsCamel))
        self.resetAt =
            (try? container.decodeIfPresent(Int.self, forKey: .resetAt))
            ?? (try? container.decodeIfPresent(Int.self, forKey: .resetAtCamel))
    }
}
