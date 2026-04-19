// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ForgeServer",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ForgeServer", targets: ["ForgeServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "ForgeServer",
            dependencies: [
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
                .product(name: "HummingbirdWSCompression", package: "hummingbird-websocket"),
            ],
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
            ]
        ),
    ]
)
