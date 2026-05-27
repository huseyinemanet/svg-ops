// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SVGOps",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SVGOps", targets: ["SVGOps"]),
        .executable(name: "SVGOpsSelfTests", targets: ["SVGOpsSelfTests"]),
        .library(name: "SVGOpsCore", targets: ["SVGOpsCore"])
    ],
    targets: [
        .target(
            name: "SVGOpsCore",
            path: "Sources/SVGOpsCore",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "SVGOps",
            dependencies: ["SVGOpsCore"],
            path: "Sources/SVGOpsApp"
        ),
        .executableTarget(
            name: "SVGOpsSelfTests",
            dependencies: ["SVGOpsCore"],
            path: "Sources/SVGOpsSelfTests"
        )
    ]
)
