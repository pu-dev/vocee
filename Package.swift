// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "VoiceScribe",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(
      name: "VoiceScribe",
      path: "Sources/VoiceScribe"
    )
  ]
)
