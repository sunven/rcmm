// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RCMMShared",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "RCMMShared",
            type: .static,
            targets: ["RCMMShared"]
        ),
    ],
    targets: [
        .target(
            name: "RCMMShared",
            path: "Sources"
        ),
        .testTarget(
            name: "RCMMSharedTests",
            dependencies: ["RCMMShared"],
            path: "Tests/RCMMSharedTests"
        ),
    ]
)
