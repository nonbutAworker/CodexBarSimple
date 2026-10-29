import AppKit
import OSLog
import SwiftUI

final class MenuBarHostingView: NSHostingView<TraeMenuBarUsage> {
    func followSystemAppearance() {
        // The menu bar can choose a wallpaper-dependent appearance instead of the system theme.
        self.applySystemAppearance()
        self.appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.applySystemAppearance()
            }
        }
    }

    func updateContent(_ content: TraeMenuBarUsage) {
        var content = content
        content.systemColorScheme = self.rootView.systemColorScheme
        self.rootView = content
    }

    private func applySystemAppearance() {
        let appearance = NSApplication.shared.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        self.appearance = appearance
        self.rootView.systemColorScheme = isDark ? .dark : .light
        self.logger.info("Menu bar appearance: \(appearance.name.rawValue, privacy: .public), dark: \(isDark)")
    }

    // Keep native glass live while letting the status button handle all mouse events.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    private var appearanceObservation: NSKeyValueObservation?
    private let logger = Logger(subsystem: "app.codexbarsimple.CodexBarSimple", category: "MenuBar")
}
