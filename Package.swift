import PackageDescription

let package = Package(
    name: "ReactiveSwift",
    dependencies: [
        .Package(url: "https://github.com/antitypical/Result.git", "3.0.0-alpha.3")
    ],
    exclude: [
        "Sources/Deprecations+Removals.swift",
    ]
)
