import SwiftUI

@main
struct CodexBarSimpleApp: App {
    @NSApplicationDelegateAdaptor(CodexBarSimpleApplicationDelegate.self)
    private var applicationDelegate

    init() {
        TraeFontRegistrar.register()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
