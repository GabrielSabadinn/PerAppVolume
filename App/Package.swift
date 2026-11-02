// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PerAppVolume",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "AudioEngine", targets: ["AudioEngine"]),
        .executable(name: "EngineCLI", targets: ["EngineCLI"]),
    ],
    targets: [
        .target(
            name: "AudioEngine",
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Accelerate"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "EngineCLI",
            dependencies: ["AudioEngine"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
