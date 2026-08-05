import AppKit
import Foundation
import SwiftUI
import Testing

@testable import CodexBarSimple

@MainActor
struct TraeMenuBarUsageRenderingTests {
    @Test
    func `renders the persistent TRAE menu bar usage card`() throws {
        TraeFontRegistrar.register()

        let renderer = ImageRenderer(
            content: TraeMenuBarUsage(
                value: "6%",
                remainingPercent: 6
            )
            .fixedSize())
        renderer.scale = 2

        let image = try #require(renderer.nsImage)
        #expect(image.size.width == 80)
        #expect(image.size.height == 22)

        if let outputPath = ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_MENU_QA_SNAPSHOT_PATH"] {
            try Self.writePNG(image, to: outputPath)
        }

        if let outputPath = ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_RESET_QA_SNAPSHOT_PATH"] {
            let resetRenderer = ImageRenderer(
                content: TraeMenuBarUsage(
                    value: "100%",
                    remainingPercent: 100,
                    resetEmphasis: 1
                )
                .fixedSize())
            resetRenderer.scale = 2

            let resetImage = try #require(resetRenderer.nsImage)
            try Self.writePNG(resetImage, to: outputPath)
        }
    }

    @Test
    func `uses the error tone only below ten percent`() {
        #expect(TraeMenuBarUsage(value: "6%", remainingPercent: 6).isLowRemaining)
        #expect(TraeMenuBarUsage(value: "<1%", remainingPercent: 0.5).isLowRemaining)
        #expect(!TraeMenuBarUsage(value: "10%", remainingPercent: 10).isLowRemaining)
        #expect(!TraeMenuBarUsage(value: "--%", remainingPercent: nil).isLowRemaining)
    }

    @Test
    func `uses the largest fitting metric during reset emphasis`() {
        let normal = TraeMenuBarUsage(value: "100%", remainingPercent: 100)
        let emphasized = TraeMenuBarUsage(
            value: "100%",
            remainingPercent: 100,
            resetEmphasis: 1)

        #expect(normal.metricFontSize == 14)
        #expect(!normal.isResetEmphasized)
        #expect(emphasized.metricFontSize == 16)
        #expect(emphasized.isResetEmphasized)
    }

    private static func writePNG(_ image: NSImage, to outputPath: String) throws {
        let tiffData = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: tiffData))
        let pngData = try #require(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
}
