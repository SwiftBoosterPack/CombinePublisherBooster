// swift-tools-version: 5.7

import PackageDescription

let package = Package(
  name: "CombinePublisherBooster",
  platforms: [
    .iOS(.v16), .macOS(.v12), .macCatalyst(.v13),
  ],
  products: [
    .library(
      name: "CombinePublisherBooster",
      targets: ["CombinePublisherBooster"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/SwiftBoosterPack/CombineTestingBooster.git", branch: "main")
  ],
  targets: [
    .target(
      name: "CombinePublisherBooster",
      path: "CombinePublisherBooster",
      exclude: []
    ),
    .testTarget(
      name: "CombinePublisherBoosterTests",
      dependencies: [
        "CombinePublisherBooster",
        .product(name: "CombineTesting", package: "CombineTestingBooster")
      ],
      path: "CombinePublisherBoosterTests"
    ),
  ]
)

