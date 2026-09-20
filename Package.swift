// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wine-shell",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WineKit", targets: ["WineKit"]),
    ],
    targets: [
        .target(name: "WineKit", path: "Sources/WineKit"),
        .testTarget(name: "WineKitTests", dependencies: ["WineKit"], path: "Tests/WineKitTests"),
    ]
)
