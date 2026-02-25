// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DigitFlip",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(
            name: "DigitFlip",
            path: "DigitFlip",
            exclude: [
                "DigitFlipApp.swift",
                "Views"
            ],
            resources: [
                .copy("Resources/GlyphSets")
            ]
        ),
        .testTarget(
            name: "DigitFlipTests",
            dependencies: ["DigitFlip"],
            path: "DigitFlipTests"
        ),
    ]
)
