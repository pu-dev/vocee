import AppKit
import SwiftUI
import VoceeCore

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

      Toggle("Paste into active app when done", isOn: $settings.pasteOnFinish)

      VStack(alignment: .leading, spacing: 4) {
        Text("Speech-to-text server")
        Picker("", selection: $settings.sttBackend) {
          ForEach(SttBackend.allCases, id: \.self) { backend in
            Text(backend.displayName).tag(backend)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
      }

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
