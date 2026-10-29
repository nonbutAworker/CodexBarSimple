import AppKit
import SwiftUI

final class MenuBarHostingView: NSHostingView<TraeMenuBarUsage> {
    // Keep native glass live while letting the status button handle all mouse events.
    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
