// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "libgit2.swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "libgit2.swift",
            targets: ["libgit2.swift"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "Cgit2",
            url: "https://github.com/k-ymmt/libgit2.swift/releases/download/v0.1.0/libgit2.xcframework.zip",
            checksum: "31f84a90e9fa8887b4e45280d01a1ca06b8c2134293dbaf30b627ec2094db46b"
        ),
        .target(
            name: "libgit2.swift",
            dependencies: ["Cgit2"],
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("GSS"),
                .linkedLibrary("z"),
                .linkedLibrary("iconv"),
            ]
        ),
        .testTarget(
            name: "libgit2.swiftTests",
            dependencies: ["libgit2.swift"]
        ),
    ]
)
