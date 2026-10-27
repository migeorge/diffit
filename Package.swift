// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DiffIt",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "DiffItApp", targets: ["DiffItApp"]),
        .executable(name: "diffit", targets: ["diffit"]),
        .library(name: "DiffCore", targets: ["DiffCore"]),
    ],
    targets: [
        .target(name: "DiffCore"),
        .target(name: "DiffItProtocol"),
        .executableTarget(name: "diffit", dependencies: ["DiffItProtocol"]),
        .executableTarget(name: "DiffItApp", dependencies: ["DiffCore", "DiffItProtocol"]),
        .testTarget(name: "DiffCoreTests", dependencies: ["DiffCore"]),
        .testTarget(name: "DiffItProtocolTests", dependencies: ["DiffItProtocol"]),
    ],
    swiftLanguageModes: [.v5]
)
