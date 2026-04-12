// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "SwiftUIRequest",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SwiftUIRequest", targets: ["SwiftUIRequest"])
    ],
    targets: [
        .target(name: "SwiftUIRequest"),
        .testTarget(name: "SwiftUIRequestTests", dependencies: ["SwiftUIRequest"])
    ],
    swiftLanguageModes: [.v6]
)
