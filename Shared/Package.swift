// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Shared",
            targets: ["Shared"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/intitni/CopilotForXcodeKit",
            branch: "feature/passing-file-content-to-extension"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.2.0"
        ),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "CodableWrappers", package: "CodableWrappers"),
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"]
        ),
    ]
)

