// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FamilyCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "FamilyCore", targets: ["FamilyCore"]),
    ],
    targets: [
        .target(name: "FamilyCore", resources: [
            .copy("Resources/family.json"),
            .copy("Resources/rotation.json"),
            .copy("Resources/tickets.json"),
        ]),
        .testTarget(name: "FamilyCoreTests", dependencies: ["FamilyCore"]),
    ]
)
