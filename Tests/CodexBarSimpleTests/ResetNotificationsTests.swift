import Foundation
import Testing
import UserNotifications

@testable import CodexBarSimple

@MainActor
struct ResetNotificationsTests {
    @Test
    func `submits a native reset notification once even after restarting`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var requests: [UNNotificationRequest] = []
        let notifier = ResetNotifications(
            defaults: fixture.defaults, authorize: { true }, deliver: { requests.append($0) })

        await notifier.notify(announcementID: "reset-1")
        await notifier.notify(announcementID: "reset-1")
        let restarted = ResetNotifications(
            defaults: fixture.defaults, authorize: { true }, deliver: { requests.append($0) })
        await restarted.notify(announcementID: "reset-1")
        await restarted.notify(announcementID: "reset-2")
        await restarted.notify(announcementID: "reset-1")

        #expect(requests.count == 2)
        let request = try #require(requests.first)
        #expect(request.identifier == "codex-reset-reset-1")
        #expect(request.trigger == nil)
        #expect(request.content.title == "Codex 额度即将重置")
        #expect(request.content.body == "已确认新的重置公告，记得尽快使用当前剩余额度。")
        #expect(request.content.sound != nil)
    }

    @Test(arguments: [
        ("2026-09-12T16:30:00Z", "Asia/Shanghai", "2026年9月13日 00:30"),
        ("2026-09-12T16:30:00Z", "America/Los_Angeles", "2026年9月12日 09:30"),
        ("2026-12-31T16:30:00Z", "Asia/Shanghai", "2027年1月1日 00:30"),
        ("2026-12-31T16:30:00Z", "America/Los_Angeles", "2026年12月31日 08:30"),
    ])
    func `shows the announced date and time in the local time zone`(
        _ timestamp: String, _ timeZoneID: String, _ expectedTime: String
    ) throws {
        let date = try #require(ISO8601DateFormatter().date(from: timestamp))
        let timeZone = try #require(TimeZone(identifier: timeZoneID))
        let body = ResetNotifications.notificationBody(scheduledFor: date, timeZone: timeZone)

        #expect(body == "预计重置时间：\(expectedTime)（本地时间）。记得尽快使用当前剩余额度。")
        #expect(ResetNotifications.notificationBody(scheduledFor: nil) == "已确认新的重置公告，记得尽快使用当前剩余额度。")
    }

    @Test
    func `native notification includes the scheduled time without repeating the announcement`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var requests: [UNNotificationRequest] = []
        let notifier = ResetNotifications(
            defaults: fixture.defaults, authorize: { true }, deliver: { requests.append($0) })
        let date = try #require(ISO8601DateFormatter().date(from: "2026-09-12T16:30:00Z"))

        await notifier.notify(announcementID: "reset-1", scheduledFor: date)
        await notifier.notify(announcementID: "reset-1", scheduledFor: date.addingTimeInterval(3600))

        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.content.body == ResetNotifications.notificationBody(scheduledFor: date))
    }

    @Test
    func `denied permission does not post or permanently suppress a notification`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var allowed = false
        var submissions = 0
        let notifier = ResetNotifications(
            defaults: fixture.defaults, authorize: { allowed }, deliver: { _ in submissions += 1 })

        await notifier.notify(announcementID: "reset-1")
        #expect(submissions == 0)
        allowed = true
        await notifier.notify(announcementID: "reset-1")
        #expect(submissions == 1)
    }

    @Test
    func `failed submissions can be retried without recording a false delivery`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var submissions = 0
        let notifier = ResetNotifications(
            defaults: fixture.defaults, authorize: { true },
            deliver: { _ in
                submissions += 1
                if submissions == 1 { throw URLError(.unknown) }
            })

        await notifier.notify(announcementID: "reset-1")
        await notifier.notify(announcementID: "reset-1")
        await notifier.notify(announcementID: "reset-1")
        #expect(submissions == 2)
    }

    @Test
    func `startup and announcement share one permission request and one submission`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var authorizations = 0
        var submissions = 0
        let notifier = ResetNotifications(
            defaults: fixture.defaults,
            authorize: {
                authorizations += 1
                try await Task.sleep(for: .milliseconds(30))
                return true
            }, deliver: { _ in submissions += 1 })

        let startup = Task { await notifier.requestAuthorization() }
        let first = Task { await notifier.notify(announcementID: "reset-1") }
        let duplicate = Task { await notifier.notify(announcementID: "reset-1") }
        _ = await startup.value
        await first.value
        await duplicate.value

        #expect(authorizations == 1)
        #expect(submissions == 1)
    }

    @Test
    func `a withdrawn announcement does not post after permission is granted`() async throws {
        let fixture = try NotificationPreferences()
        defer { fixture.remove() }
        var submissions = 0
        let notifier = ResetNotifications(
            defaults: fixture.defaults,
            authorize: {
                try await Task.sleep(for: .milliseconds(30))
                return true
            }, deliver: { _ in submissions += 1 })

        let pending = Task { await notifier.notify(announcementID: "reset-1") }
        pending.cancel()
        await pending.value
        #expect(submissions == 0)
        await notifier.notify(announcementID: "reset-1")
        #expect(submissions == 1)
    }
}

private struct NotificationPreferences {
    let suiteName: String
    let defaults: UserDefaults

    init() throws {
        self.suiteName = "CodexBarSimpleTests.Notifications.\(UUID().uuidString)"
        self.defaults = try #require(UserDefaults(suiteName: self.suiteName))
    }

    func remove() {
        self.defaults.removePersistentDomain(forName: self.suiteName)
    }
}
