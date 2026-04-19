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
            path: "artifacts/libgit2.xcframework"
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
