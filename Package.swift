// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MiniFileLogger",
    platforms: [
        .iOS(.v16), .watchOS(.v9), .visionOS(.v1), .macOS(.v13), .tvOS(.v16)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MiniFileLogger",
            targets: ["MiniFileLogger"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MiniFileLogger"),
        .testTarget(
            name: "MiniFileLoggerTests",
            dependencies: ["MiniFileLogger"]
        ),
    ]
)
