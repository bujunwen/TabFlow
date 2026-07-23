// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "TabFlow",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TabFlow", targets: ["TabFlow"])
    ],
    targets: [
        .executableTarget(
            name: "TabFlow",
            path: "Sources/TabFlow"
        )
    ]
)
