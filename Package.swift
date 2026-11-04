// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LocalVoiceInput",
    platforms: [
        .macOS(.v14),
        .iOS(.v16),
    ],
    products: [
        .library(name: "VoiceInputCore", targets: ["VoiceInputCore"]),
        .executable(name: "LocalVoiceInputMac", targets: ["LocalVoiceInputMac"]),
        .executable(name: "VoiceInputBenchmark", targets: ["VoiceInputBenchmark"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/argmaxinc/argmax-oss-swift.git",
            exact: "0.9.4"
        ),
    ],
    targets: [
        .target(name: "VoiceInputCore"),
        .executableTarget(
            name: "LocalVoiceInputMac",
            dependencies: [
                "VoiceInputCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
        .executableTarget(
            name: "VoiceInputBenchmark",
            dependencies: [
                "VoiceInputCore",
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
            ]
        ),
        .testTarget(
            name: "VoiceInputCoreTests",
            dependencies: ["VoiceInputCore"]
        ),
    ]
)
