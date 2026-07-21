// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "JobTrackerCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "JobTrackerCore", targets: ["JobTrackerCore"])
    ],
    targets: [
        .target(name: "JobTrackerCore"),
        .testTarget(name: "JobTrackerCoreTests", dependencies: ["JobTrackerCore"]),
    ]
)
