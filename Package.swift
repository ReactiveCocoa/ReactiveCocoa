// swift-tools-version:5.1

import PackageDescription

var package = Package(
    name: "ReactiveCocoa",
    products: [
        .library(name: "ReactiveCocoa", targets: ["ReactiveCocoa"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble.git", from: "8.0.1"),
        .package(url: "https://github.com/Quick/Quick.git", from: "2.0.0"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift.git", from: "6.0.0"),
    ],
    targets: [
        .target(name: "ReactiveCocoa", dependencies: ["ReactiveCocoaObjC", "ReactiveSwift"], path: "ReactiveCocoa"),
        .target(name: "ReactiveCocoaObjC", path: "ReactiveCocoaObjC"),
    ]
)

#if !os(watchOS)
package.targets += [
  .target(name: "ReactiveCocoaObjCTestSupport", path: "ReactiveCocoaObjCTestSupport"),
  .testTarget(name: "ReactiveCocoaTests", dependencies: ["Quick", "Nimble", "ReactiveCocoa", "ReactiveCocoaObjCTestSupport"], path: "ReactiveCocoaTests"),
]
#endif
