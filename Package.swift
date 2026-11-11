// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitGRPC", targets: ["AuthKitGRPC"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "AuthKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .target(
            name: "AuthKitGRPC",
            dependencies: [
                "AuthKit",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ]
        ),
        .testTarget(
            name: "AuthKitTests",
            dependencies: ["AuthKit"]
        ),
        .testTarget(
            name: "AuthKitGRPCTests",
            dependencies: [
                "AuthKitGRPC",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
