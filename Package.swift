// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AuthKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "AuthKit", targets: ["AuthKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "AuthKit",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "AuthKitTests",
            dependencies: ["AuthKit"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
