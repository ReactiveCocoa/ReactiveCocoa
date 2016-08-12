import PackageDescription

let excludes: [String]
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    excludes = [
        "Sources/Deprecations+Removals.swift",
        "Sources/ObjectiveCBridging.swift"
    ]
#else
    excludes = [
        "Sources/Deprecations+Removals.swift",
        "Sources/DynamicProperty.swift",
        "Sources/NSObject+KeyValueObserving.swift",
        "Sources/ObjectiveCBridging.swift"
    ]
#endif

let package = Package(
    name: "ReactiveCocoa",
    dependencies: [
        .Package(url: "https://github.com/antitypical/Result.git", "3.0.0-alpha.2")
    ],
    exclude: excludes
)
