// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "ReactiveCocoa",
    platforms: [
        .macOS(.v10_10), .iOS(.v8), .tvOS(.v9), .watchOS(.v2)
    ],
    products: [
        .library(name: "ReactiveCocoa", targets: ["ReactiveCocoa"])
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "6.2.0"),
        .package(url: "https://github.com/Quick/Quick.git", from: "2.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.0"),
    ],
    targets: [
        .target(
            name: "ReactiveCocoaObjC",
            dependencies: [],
            path: "ReactiveCocoaObjC"),

        .target(
            name: "ReactiveCocoa",
            dependencies: ["ReactiveSwift", "ReactiveCocoaObjC"],
            path: "ReactiveCocoa"),

        .target(
            name: "ReactiveCocoaObjCTestSupport",
            path: "ReactiveCocoaObjCTestSupport"),

        .testTarget(
            name: "ReactiveCocoaTests",
            dependencies: [
                "ReactiveCocoa",
                "ReactiveCocoaObjCTestSupport",
                "Quick",
                "Nimble"
            ],
            path: "ReactiveCocoaTests"),
    ]
)
