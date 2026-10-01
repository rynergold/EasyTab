// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EasyTab",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "EasyTab", targets: ["EasyTab"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "EasyTab",
            dependencies: [],
            path: "Sources/EasyTab"
        ),
        .testTarget(
            name: "EasyTabTests",
            dependencies: ["EasyTab"],
            path: "Tests/EasyTabTests"
        )
    ]
)
