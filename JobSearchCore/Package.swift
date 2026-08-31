// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "JobSearchCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "JobSearchCore", targets: ["JobSearchCore"]),
    ],
    targets: [
        .target(name: "JobSearchCore"),
        .testTarget(name: "JobSearchCoreTests", dependencies: ["JobSearchCore"]),
    ]
)
