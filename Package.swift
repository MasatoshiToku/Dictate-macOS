// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Dictate",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        // Shared library (cross-platform)
        .target(
            name: "DictateCore",
            path: "DictateCore"
        ),
        // macOS app
        .executableTarget(
            name: "Dictate",
            dependencies: [
                "DictateCore",
                "KeyboardShortcuts",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Dictate",
            exclude: [
                "Info.plist",
                "Dictate.entitlements",
                "Resources/AppIcon.iconset",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        // iOS app
        .executableTarget(
            name: "DictateIOS",
            dependencies: ["DictateCore"],
            path: "DictateIOS",
            exclude: [
                "Info.plist",
            ]
        ),
        // Tests
        .testTarget(
            name: "DictateTests",
            dependencies: ["DictateCore"],
            path: "DictateTests"
        ),
    ]
)
