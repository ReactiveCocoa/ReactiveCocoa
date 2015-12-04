import PackageDescription

let package = Package(
    name: "ReactiveCocoa",
    targets: [
        Target(
            name: "ReactiveCocoa"
        )
    ],
    dependencies: [
        .Package(url: "https://github.com/natestedman/Result.git", majorVersion: 1, minor: 1)
    ]
)
