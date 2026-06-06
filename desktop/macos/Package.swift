// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceBridgeAI",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VoiceBridgeAI", targets: ["VoiceBridgeAI"]),
    ],
    targets: [
        .executableTarget(
            name: "VoiceBridgeAI",
            path: "Sources/VoiceBridgeAI",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
            ]
        ),
    ]
)
