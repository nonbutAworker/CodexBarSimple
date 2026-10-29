import AppKit
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import CodexBarSimple

@MainActor
struct TraeMenuBarUsageRenderingTests {
    @Test
    func `renders the persistent TRAE menu bar usage card`() throws {
        TraeFontRegistrar.register()

        let renderer = ImageRenderer(
            content: TraeMenuBarUsage(
                value: "96%",
                remainingPercent: 96
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

        if let outputPath = ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_LUNA_QA_SNAPSHOT_PATH"] {
            let lunaRenderer = ImageRenderer(
                content: TraeMenuBarUsage(
                    value: "97%",
                    remainingPercent: 97,
                    isLunaReserve: true
                )
                .fixedSize())
            lunaRenderer.scale = 2

            let lunaImage = try #require(lunaRenderer.nsImage)
            try Self.writePNG(lunaImage, to: outputPath)
        }

        if let outputPath = ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_NOTICE_QA_SNAPSHOT_PATH"] {
            let noticeRenderer = ImageRenderer(
                content: VStack(spacing: 6) {
                    TraeMenuBarUsage(value: "96%", remainingPercent: 96)
                    TraeMenuBarUsage(value: "96%", remainingPercent: 96, isResetScheduled: true)
                    TraeMenuBarUsage(value: "95%", remainingPercent: 95, isLunaReserve: true, isResetScheduled: true)
                    TraeMenuBarUsage(value: "6%", remainingPercent: 6, isResetScheduled: true)
                    TraeMenuBarUsage(value: "100%", remainingPercent: 100, resetEmphasis: 1, isResetScheduled: true)
                }
                .padding(8)
                .fixedSize())
            noticeRenderer.scale = 3
            try Self.writePNG(try #require(noticeRenderer.nsImage), to: outputPath)
        }

        if let outputPath = ProcessInfo.processInfo.environment["CODEXBAR_SIMPLE_BELL_QA_GIF_PATH"] {
            try Self.writeBellGIF(to: outputPath)
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
    func `hosts live glass without intercepting status button clicks`() {
        let host = MenuBarHostingView(rootView: TraeMenuBarUsage(value: "33%", remainingPercent: 33))
        host.frame = NSRect(x: 0, y: 0, width: 80, height: 22)

        #expect(!host.isOpaque)
        #expect(host.hitTest(NSPoint(x: 40, y: 11)) == nil)

        host.rootView = TraeMenuBarUsage(value: "6%", remainingPercent: 6, isResetScheduled: true)
        #expect(host.rootView.value == "6%")
        #expect(host.rootView.isLowRemaining)
        #expect(host.rootView.isResetScheduled)
        #expect(host.frame.size == NSSize(width: 80, height: 22))
    }

    @Test(arguments: [ColorScheme.light, .dark])
    func `keeps the compact layout in both system appearances`(colorScheme: ColorScheme) throws {
        let renderer = ImageRenderer(
            content: TraeMenuBarUsage(value: "33%", remainingPercent: 33)
                .environment(\.colorScheme, colorScheme))
        let image = try #require(renderer.nsImage)

        #expect(image.size == NSSize(width: 80, height: 22))
    }

    @Test
    func `follows system appearance changes instead of its menu bar parent`() async throws {
        let application = NSApplication.shared
        let originalAppearance = application.appearance
        defer { application.appearance = originalAppearance }

        let parent = NSView()
        let host = MenuBarHostingView(rootView: TraeMenuBarUsage(value: "33%", remainingPercent: 33))
        parent.addSubview(host)
        host.followSystemAppearance()

        for appearanceName in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
            parent.appearance = NSAppearance(named: appearanceName == .aqua ? .darkAqua : .aqua)
            application.appearance = NSAppearance(named: appearanceName)

            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(1))
            while host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) != appearanceName,
                clock.now < deadline
            {
                try await Task.sleep(for: .milliseconds(5))
            }

            #expect(host.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == appearanceName)
            #expect(host.rootView.value == "33%")
            #expect(host.hitTest(NSPoint(x: 40, y: 11)) == nil)
        }
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

    private static func writeBellGIF(to outputPath: String) throws {
        let destination = try #require(
            CGImageDestinationCreateWithURL(
                URL(fileURLWithPath: outputPath) as CFURL, UTType.gif.identifier as CFString, 20, nil))
        CGImageDestinationSetProperties(
            destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let start = CFAbsoluteTimeGetCurrent()
        for frame in 0..<20 {
            let renderer = ImageRenderer(
                content: TraeMenuBarUsage(
                    value: "96%", remainingPercent: 96, isResetScheduled: true,
                    bellRotation: ResetBellMotion.rotation(at: 0.8 + Double(frame) * 0.04)
                )
                .padding(8)
                .fixedSize())
            renderer.scale = 3
            CGImageDestinationAddImage(
                destination, try #require(renderer.cgImage),
                [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.04]] as CFDictionary)
        }
        #expect(CGImageDestinationFinalize(destination))
        print("BELL_QA_FRAME_MEAN_MS=\((CFAbsoluteTimeGetCurrent() - start) * 1000 / 20)")
    }
}
