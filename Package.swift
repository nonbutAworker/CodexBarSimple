// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CodexBarSimple",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexBarSimple", targets: ["CodexBarSimple"])
    ],
    targets: [
        .executableTarget(
            name: "CodexBarSimple",
            resources: [
                .copy("Resources/Fonts")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]),
        .testTarget(
            name: "CodexBarSimpleTests",
            dependencies: ["CodexBarSimple"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ]),
    ])
