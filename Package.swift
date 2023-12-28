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
  targets: [
    .target(
      name: "CombinePublisherBooster",
      path: "CombinePublisherBooster",
      exclude: []
    ),
    .testTarget(
      name: "CombinePublisherBoosterTests",
      dependencies: ["CombinePublisherBooster"],
      path: "CombinePublisherBoosterTests"
    ),
  ]
)

