// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TapSpike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "TapSpike",
            path: "Sources/TapSpike",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Accelerate"),
            ]
        ),
    ]
)
