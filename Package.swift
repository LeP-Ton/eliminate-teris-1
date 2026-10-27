// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "EliminateTeris1",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "Eliminate Teris 1", targets: ["EliminateTeris1"])
    ],
    targets: [
        .executableTarget(
            name: "EliminateTeris1",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(name: "EliminateTeris1Tests", dependencies: ["EliminateTeris1"], path: "Tests")
    ]
)
