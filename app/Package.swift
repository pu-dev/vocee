// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Vocee",
  platforms: [.macOS(.v13)],
  targets: [
    .target(
      name: "VoceeCore",
      path: "Sources/VoceeCore"
    ),
    .executableTarget(
      name: "Vocee",
      dependencies: ["VoiceScribeCore"],
      path: "Sources/Vocee"
    ),
    .executableTarget(
      name: "vocee-cli",
      dependencies: ["VoceeCore"],
      path: "Sources/vocee-cli"
    ),
  ]
)
