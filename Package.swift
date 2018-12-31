// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "pyTanks.SwiftBrain",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "runSample",
            targets: ["runSample"]),
        .library(
            name: "PyBrain",
            targets: ["Brain"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/matthewseaman/pyTanks.SwiftPlayer", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "runSample",
            dependencies: ["AdvancedPlayer", "ClientControl"]),
        .target(
            name: "AdvancedPlayer",
            dependencies: ["Brain", "PlayerSupport"]),
        .target(
            name: "Brain",
            dependencies: ["Navigate", "Artillery", "PlayerSupport"]),
        .target(
            name: "Artillery",
            dependencies: ["Navigate", "PlayerSupport"]),
        .target(
            name: "Navigate",
            dependencies: ["Compute"]),
        .target(
            name: "Compute",
            dependencies: []),
    ]
)
