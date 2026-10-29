import AppKit
import SwiftUI

final class MenuBarHostingView: NSHostingView<TraeMenuBarUsage> {
    func followSystemAppearance() {
        // The menu bar can choose a wallpaper-dependent appearance instead of the system theme.
        self.appearance = NSApplication.shared.effectiveAppearance
        self.appearanceObservation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.appearance = NSApplication.shared.effectiveAppearance
            }
        }
    }

    // Keep native glass live while letting the status button handle all mouse events.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    private var appearanceObservation: NSKeyValueObservation?
}
