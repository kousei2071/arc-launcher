// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "arc-launcher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CyberLauncher", targets: ["CyberLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "CyberLauncher",
            path: "Sources/CyberLauncher"
        ),
        .testTarget(
            name: "CyberLauncherTests",
            dependencies: ["CyberLauncher"],
            path: "Tests/CyberLauncherTests"
        )
    ]
)
