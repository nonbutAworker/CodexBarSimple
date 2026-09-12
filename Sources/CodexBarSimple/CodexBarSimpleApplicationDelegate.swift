import AppKit
import Observation
import SwiftUI

@MainActor
final class CodexBarSimpleApplicationDelegate: NSObject, NSApplicationDelegate {
    private let model = UsageModel()

    private var statusItem: NSStatusItem?
    private var refreshTask: Task<Void, Never>?
    private var resetAnimationTask: Task<Void, Never>?
    private var handledResetEventID = 0
    private var resetEmphasis: CGFloat = 0
    private let resetNotice = ResetNoticeModel()
    private var resetNoticeTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_: Notification) {
        self.installStatusItem()
        self.observeUsage()
        self.refreshTask = Task {
            await self.model.runRefreshLoop()
        }
        self.resetNoticeTask = Task {
            await self.resetNotice.runRefreshLoop()
        }
    }

    func applicationWillTerminate(_: Notification) {
        self.refreshTask?.cancel()
        self.resetAnimationTask?.cancel()
        self.resetNoticeTask?.cancel()
    }

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: 84)
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(self.handleStatusItemClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.setAccessibilityLabel(self.model.accessibilityLabel)
        self.statusItem = statusItem

        self.updateStatusItem()
    }

    private func observeUsage() {
        withObservationTracking {
            _ = self.model.displayText
            _ = self.model.remainingPercent
            _ = self.model.displayKind
            _ = self.model.resetEventID
            _ = self.resetNotice.isResetScheduled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.handleUsageChange()
                self.observeUsage()
            }
        }
    }

    private func handleUsageChange() {
        guard self.model.resetEventID != self.handledResetEventID else {
            self.updateStatusItem()
            return
        }

        self.handledResetEventID = self.model.resetEventID
        self.startResetAnimation()
    }

    private func updateStatusItem() {
        guard let button = self.statusItem?.button else { return }

        let renderer = ImageRenderer(
            content: TraeMenuBarUsage(
                value: self.model.displayText,
                remainingPercent: self.model.remainingPercent,
                isLunaReserve: self.model.displayKind?.isLunaReserve == true,
                resetEmphasis: self.resetEmphasis,
                isResetScheduled: self.resetNotice.isResetScheduled))
        renderer.scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else { return }
        image.isTemplate = false
        button.image = image
        button.setAccessibilityLabel(self.model.accessibilityLabel)
        button.setAccessibilityValue(self.model.displayText)
        button.setAccessibilityHelp(
            self.resetNotice.isResetScheduled
                ? "A Codex quota reset is announced and awaiting execution. Orange border: use your remaining quota soon."
                : nil)
    }

    private func startResetAnimation() {
        self.resetAnimationTask?.cancel()
        self.resetEmphasis = 0
        self.updateStatusItem()

        self.resetAnimationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                for frame in 1...8 {
                    let progress = CGFloat(frame) / 8
                    let inverse = 1 - progress
                    self.resetEmphasis = 1 - inverse * inverse * inverse
                    self.updateStatusItem()
                    try await Task.sleep(for: .milliseconds(30))
                }

                try await Task.sleep(for: .milliseconds(900))

                for frame in 1...12 {
                    let progress = CGFloat(frame) / 12
                    let easedProgress = progress * progress * (3 - 2 * progress)
                    self.resetEmphasis = 1 - easedProgress
                    self.updateStatusItem()
                    try await Task.sleep(for: .milliseconds(33))
                }
            } catch {
                return
            }

            self.resetEmphasis = 0
            self.updateStatusItem()
        }
    }

    @objc
    private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard
            let event = NSApp.currentEvent,
            event.type == .rightMouseUp
                || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        else {
            return
        }

        let menu = NSMenu()

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(self.quit),
            keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
