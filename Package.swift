// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyLens",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyLens",
            path: "Sources/KeyLens"
        )
    ]
)
