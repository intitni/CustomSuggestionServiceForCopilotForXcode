// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shared",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "Shared",
            targets: ["Shared", "SuggestionService"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/intitni/CopilotForXcodeKit",
            from: "0.3.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies",
            from: "1.2.0"
        ),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.4"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
    ],
    targets: [
        .target(
            name: "Shared",
            dependencies: [
                .product(name: "CodableWrappers", package: "CodableWrappers"),
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
                .product(name: "Parsing", package: "swift-parsing"),
            ]
        ),
        .testTarget(
            name: "SharedTests",
            dependencies: ["Shared"]
        ),
        .target(
            name: "SuggestionService",
            dependencies: [
                "Shared",
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
                .product(name: "Parsing", package: "swift-parsing"),
            ]
        ),
        .testTarget(
            name: "SuggestionServiceTests",
            dependencies: ["SuggestionService"]
        ),
    ]
)

