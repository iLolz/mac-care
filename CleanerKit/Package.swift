// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CleanerKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CleanerKit", targets: ["CleanerKit"]),
    ],
    targets: [
        .target(name: "CleanerKit"),
        .testTarget(name: "CleanerKitTests", dependencies: ["CleanerKit"]),
    ]
)
