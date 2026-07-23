// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CandidoCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "CandidoCore", targets: ["CandidoCore"])
    ],
    targets: [
        .target(name: "CandidoCore"),
        .testTarget(name: "CandidoCoreTests", dependencies: ["CandidoCore"]),
    ]
)
