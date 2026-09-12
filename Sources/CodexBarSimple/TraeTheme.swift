import CoreText
import Foundation
import SwiftUI

enum TraeTheme {
    enum Palette {
        static let surface = Color(red: 0x22 / 255, green: 0x24 / 255, blue: 0x27 / 255)
        static let overlay3 = Color(red: 0xE0 / 255, green: 0xE2 / 255, blue: 0xF2 / 255, opacity: 0.08)
        static let accentTeal = Color(red: 0x2D / 255, green: 0xD2 / 255, blue: 0x88 / 255)
        static let reserveGold = Color(red: 0xE1 / 255, green: 0xB0 / 255, blue: 0x00 / 255)
        static let statusError = Color(red: 0xF6 / 255, green: 0x5A / 255, blue: 0x5A / 255)

        static let text = Color(red: 0xD1 / 255, green: 0xD3 / 255, blue: 0xDB / 255)
        static let textHover = Color(red: 0xF5 / 255, green: 0xF9 / 255, blue: 0xFE / 255)

        static let border2 = Color(red: 0xE0 / 255, green: 0xE2 / 255, blue: 0xF2 / 255, opacity: 0.16)
        static let statusWarning = Color(red: 0xD2 / 255, green: 0x7E / 255, blue: 0x24 / 255)
    }

    enum Radius {
        static let medium: CGFloat = 6
    }

    enum Spacing {
        static let compact: CGFloat = 4
        static let control: CGFloat = 6
    }

    enum Typography {
        static let menuMetricSize: CGFloat = 14
        static let resetMetricSize: CGFloat = 16
        static let menuLabel = Font.system(size: 5, weight: .medium)

        static func menuMetric(size: CGFloat) -> Font {
            Font.custom("JetBrainsMono-SemiBold", fixedSize: size)
        }
    }
}

enum TraeResources {
    static func url(
        forResource name: String,
        withExtension extensionName: String,
        subdirectory: String
    ) -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let installedResourceURL =
                resourceURL
                .appendingPathComponent("CodexBarSimple_CodexBarSimple.bundle")
                .appendingPathComponent(subdirectory)
                .appendingPathComponent("\(name).\(extensionName)")

            if FileManager.default.fileExists(atPath: installedResourceURL.path) {
                return installedResourceURL
            }
        }

        return Bundle.module.url(
            forResource: name,
            withExtension: extensionName,
            subdirectory: subdirectory)
    }
}

@MainActor
enum TraeFontRegistrar {
    private static var didRegister = false

    static func register() {
        guard !self.didRegister else { return }
        self.didRegister = true

        for name in ["JetBrainsMono-SemiBold"] {
            guard
                let url = TraeResources.url(
                    forResource: name,
                    withExtension: "ttf",
                    subdirectory: "Fonts")
            else {
                continue
            }

            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
