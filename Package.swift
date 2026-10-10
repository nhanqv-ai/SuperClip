// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SuperClip",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SuperClipCore",
            targets: ["SuperClipCore"]
        ),
        .executable(
            name: "SuperClip",
            targets: ["SuperClip"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SuperClipCore",
            dependencies: [],
            path: "Sources/SuperClipCore"
        ),
        .executableTarget(
            name: "SuperClip",
            dependencies: ["SuperClipCore"],
            path: "Sources/SuperClip"
        )
    ]
)
