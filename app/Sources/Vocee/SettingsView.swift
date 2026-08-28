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
        Text("MLX whisper server")
        TextField("http://127.0.0.1:9991", text: $settings.sttBaseUrl)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("Whisper model")
        Picker("", selection: $settings.whisperModel) {
          ForEach(WhisperModel.allCases, id: \.self) { model in
            Text(model.displayName).tag(model)
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
