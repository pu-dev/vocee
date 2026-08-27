// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "VoiceScribe",
  platforms: [.macOS(.v13)],
  targets: [
    .target(
      name: "VoiceScribeCore",
      path: "Sources/VoiceScribeCore"
    ),
    .executableTarget(
      name: "VoiceScribe",
      dependencies: ["VoiceScribeCore"],
      path: "Sources/VoiceScribe"
    ),
    .executableTarget(
      name: "voicescribe-cli",
      dependencies: ["VoiceScribeCore"],
      path: "Sources/voicescribe-cli"
    ),
  ]
)
