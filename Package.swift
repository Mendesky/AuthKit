// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
        .library(name: "AuthKitGRPC", targets: ["AuthKitGRPC"]),
        .library(name: "AuthKitEventSourcing", targets: ["AuthKitEventSourcing"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.8.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
        .package(url: "https://github.com/gradyzhuo/swift-ddd-kit.git", from: "1.4.0"),
        .package(url: "https://github.com/gradyzhuo/swift-kurrentdb.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "AuthKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
            ]
        ),
        .target(
            name: "AuthKitGRPC",
            dependencies: [
                "AuthKit",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ]
        ),
        .target(
            name: "AuthKitEventSourcing",
            dependencies: [
                "AuthKit",
                .product(name: "DDDKit", package: "swift-ddd-kit"),
            ]
        ),
        .testTarget(
            name: "AuthKitTests",
            dependencies: [
                "AuthKit",
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
            ],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(
            name: "AuthKitGRPCTests",
            dependencies: [
                "AuthKitGRPC",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
            ]
        ),
        .testTarget(
            name: "AuthKitEventSourcingTests",
            dependencies: [
                "AuthKitEventSourcing",
                "AuthKit",
                .product(name: "DDDKit", package: "swift-ddd-kit"),
                .product(name: "TestUtility", package: "swift-ddd-kit"),
                .product(name: "KurrentDB", package: "swift-kurrentdb"),
            ],
            resources: [
                .process("event-generator-config.yaml"),
                .process("event.yaml"),
                .process("projection-model.yaml"),
            ],
            plugins: [
                .plugin(name: "DomainEventGeneratorPlugin", package: "swift-ddd-kit"),
                .plugin(name: "ModelGeneratorPlugin", package: "swift-ddd-kit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
