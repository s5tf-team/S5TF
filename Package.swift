// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "S5TF",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "S5TF",
            targets: ["S5TF"])
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "S5TF",
            dependencies: []),
        .testTarget(
            name: "S5TFTests",
            dependencies: ["S5TF"])
    ]
)
