// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "LiDARKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "LiDARKit",
            targets: ["LiDARKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LiDARKit",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LiDARKitTests",
            dependencies: ["LiDARKit"]
        )
    ]
) 