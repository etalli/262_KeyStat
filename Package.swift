// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyCounter",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyCounter",
            path: "Sources/KeyCounter"
        )
    ]
)
