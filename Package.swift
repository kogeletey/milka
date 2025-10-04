// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mise-milka",
    products: [
        .executable(
            name: "mise-milka",
            targets: ["mise-milka"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "mise-milka",
            dependencies: [
                .product(name: "TOMLKit", package: "TOMLKit")
            ],
            path: "Sources/MiseMilka"
        ),
        .testTarget(
            name: "MiseMilkaTests",
            dependencies: ["mise-milka"],
            path: "Tests/MiseMilkaTests"
        ),
    ]
)
