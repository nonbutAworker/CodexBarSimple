import Foundation
import OSLog
import UserNotifications

@MainActor
final class ResetNotifications {
    private let defaults: UserDefaults
    private let authorize: () async throws -> Bool
    private let deliver: (UNNotificationRequest) async throws -> Void
    private var authorizationTask: Task<Bool, Never>?
    private var inFlightIDs: Set<String> = []
    private let historyKey = "notifiedResetAnnouncementIDs"
    private let logger = Logger(subsystem: "app.codexbarsimple.CodexBarSimple", category: "Notifications")

    init(
        defaults: UserDefaults = .standard,
        authorize: @escaping () async throws -> Bool = {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                return try await center.requestAuthorization(options: [.alert, .sound])
            case .authorized, .provisional:
                return true
            default:
                return false
            }
        },
        deliver: @escaping (UNNotificationRequest) async throws -> Void = {
            try await UNUserNotificationCenter.current().add($0)
        }
    ) {
        self.defaults = defaults
        self.authorize = authorize
        self.deliver = deliver
    }

    func requestAuthorization() async -> Bool {
        if let authorizationTask {
            return await authorizationTask.value
        }
        let task = Task {
            do {
                return try await self.authorize()
            } catch {
                self.logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }
        self.authorizationTask = task
        defer { self.authorizationTask = nil }
        let granted = await task.value
        self.logger.notice("Notification permission granted: \(granted)")
        return granted
    }

    func notify(announcementID: String, scheduledFor: Date? = nil) async {
        guard
            !(self.defaults.stringArray(forKey: self.historyKey) ?? []).contains(announcementID),
            self.inFlightIDs.insert(announcementID).inserted
        else { return }
        defer { self.inFlightIDs.remove(announcementID) }

        guard await self.requestAuthorization(), !Task.isCancelled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Codex 额度即将重置"
        content.body = Self.notificationBody(scheduledFor: scheduledFor)
        content.sound = .default
        content.threadIdentifier = "codex-reset-announcements"
        let request = UNNotificationRequest(identifier: "codex-reset-\(announcementID)", content: content, trigger: nil)

        do {
            try await self.deliver(request)
            var notifiedIDs = self.defaults.stringArray(forKey: self.historyKey) ?? []
            notifiedIDs.append(announcementID)
            self.defaults.set(notifiedIDs, forKey: self.historyKey)
        } catch {
            // Failed submissions must not suppress a later notification for this announcement.
            self.logger.error("Reset notification submission failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func notificationBody(scheduledFor: Date?, timeZone: TimeZone = .current) -> String {
        guard let scheduledFor else { return "已确认新的重置公告，记得尽快使用当前剩余额度。" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        return "预计重置时间：\(formatter.string(from: scheduledFor))（本地时间）。记得尽快使用当前剩余额度。"
    }
}
