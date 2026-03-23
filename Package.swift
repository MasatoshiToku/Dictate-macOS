// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Dictate",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "Dictate",
            dependencies: [
                "KeyboardShortcuts",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Dictate",
            exclude: [
                "Info.plist",
                "Dictate.entitlements",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "DictateTests",
            dependencies: ["Dictate"],
            path: "DictateTests"
        ),
    ]
)
