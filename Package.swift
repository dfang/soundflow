// swift-tools-version: 5.10

import Foundation
import PackageDescription

let packageDirectory = FileManager.default.currentDirectoryPath
let sherpaLibDirectory = "\(packageDirectory)/Vendor/sherpa-onnx/lib"

let package = Package(
    name: "SoundFlow",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SoundFlow", targets: ["SoundFlow"]),
    ],
    targets: [
        .systemLibrary(
            name: "CSherpaOnnx",
            path: "Sources/CSherpaOnnx"
        ),
        .executableTarget(
            name: "SoundFlow",
            dependencies: [
                "CSherpaOnnx",
            ],
            path: "Sources",
            exclude: [
                "CSherpaOnnx",
            ],
            resources: [
                .process("system_dictionary.json"),
            ],
            linkerSettings: [
                .linkedLibrary("onnxruntime"),
                .unsafeFlags([
                    "-L", sherpaLibDirectory,
                    "-Xlinker", "-rpath",
                    "-Xlinker", sherpaLibDirectory,
                ]),
            ]
        ),
    ]
)
