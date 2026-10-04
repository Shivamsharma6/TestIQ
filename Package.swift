// swift-tools-version: 6.0
import PackageDescription

// The app target picks these same files up through Xcode's folder synchronisation.
// This package exists so `swift test` can exercise the pure-Foundation core on the
// command line, without booting a simulator.
let package = Package(
    name: "TestIQCore",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "IQCore",
            path: "TestIQ",
            exclude: ["App", "Components", "Design", "Features", "Assets.xcassets", "Info.plist", "Services/AppState.swift", "Services/SoundEngine.swift", "Services/HapticsEngine.swift"],
            sources: ["Core", "Services/ProgressStore.swift"],
            // Matches SWIFT_VERSION = 5.0 in the Xcode target, so the two build systems
            // agree on concurrency semantics and cannot disagree about what compiles.
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IQCoreTests",
            dependencies: ["IQCore"],
            path: "Tools/IQCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
