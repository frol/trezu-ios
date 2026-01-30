// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NearTreasury",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NearTreasury",
            targets: ["NearTreasury"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "NearTreasury",
            dependencies: [],
            path: "NearTreasury"
        )
    ]
)
