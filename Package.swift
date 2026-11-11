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
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.0.0"),
        .package(url: "git@github.com:Mendesky/DDDKit.git", from: "1.12.0"),
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
        .target(
            name: "AuthKitEventSourcing",
            dependencies: [
                "AuthKit",
                .product(name: "DDDKit", package: "DDDKit"),
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
        .testTarget(
            name: "AuthKitEventSourcingTests",
            dependencies: [
                "AuthKitEventSourcing",
                "AuthKit",
                .product(name: "DDDKit", package: "DDDKit"),
                .product(name: "TestUtility", package: "DDDKit"),
            ],
            resources: [
                .process("event-generator-config.yaml"),
                .process("event.yaml"),
                .process("projection-model.yaml"),
            ],
            plugins: [
                .plugin(name: "DomainEventGeneratorPlugin", package: "DDDKit"),
                .plugin(name: "ProjectionModelGeneratorPlugin", package: "DDDKit"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
