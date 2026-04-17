// swift-tools-version: 6.3

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SwiftUIRequest",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v13),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "SwiftUIRequest", targets: ["SwiftUIRequest", "MacrosDefine"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
    ],
    targets: [
        
        .target(name: "SwiftUIRequest"),
        .macro(
            name: "Macros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        .target(name: "MacrosDefine", dependencies: ["Macros"]),
        .testTarget(name: "SwiftUIRequestTests", dependencies: ["SwiftUIRequest"])
    ],
    swiftLanguageModes: [.v6]
)
