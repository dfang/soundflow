// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SoundFlow",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SoundFlow", targets: ["SoundFlow"]),
    ],
    targets: [
        .executableTarget(
            name: "SoundFlow",
            path: "Sources"
        ),
    ]
)
