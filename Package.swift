// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LangGraph",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LangGraph",
            targets: ["LangGraph"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LangGraph", dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ], resources: [ .process("Resources")]),
        .testTarget(
            name: "LangGraphTests",
            dependencies: ["LangGraph"]),
    ]
)
