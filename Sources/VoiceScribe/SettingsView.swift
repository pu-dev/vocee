import AppKit
import SwiftUI

struct SettingsView: View {
  @ObservedObject var settings: Settings

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Settings")
        .font(.headline)

      VStack(alignment: .leading, spacing: 4) {
        Text("Waveform bar size")
        HStack {
          Slider(value: $settings.barScale, in: 0.5...2.0, step: 0.1)
          Text(String(format: "%.1f×", settings.barScale))
            .monospacedDigit()
            .frame(width: 40, alignment: .trailing)
        }
      }

      Toggle("Copy transcript to clipboard", isOn: $settings.copyToClipboard)

      HStack {
        Spacer()
        Button("Done") {
          NSApp.keyWindow?.close()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(16)
    .frame(width: 320)
  }
}
