// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "TouchBarMatch",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "TouchBarMatch", targets: ["TouchBarMatch"])
    ],
    targets: [
        .executableTarget(
            name: "TouchBarMatch",
            path: "Sources"
        )
    ]
)
