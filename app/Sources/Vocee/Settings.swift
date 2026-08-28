import Foundation
import VoceeCore

@MainActor
final class Settings: ObservableObject {
  static let shared = Settings()

  private enum Keys {
    static let barScale = "waveformBarScale"
    static let pasteOnFinish = "pasteOnFinish"
    static let sttBaseUrl = "sttBaseUrl"
    static let whisperModel = "whisperModel"
  }

  /// Multiplier applied to each waveform bar's height. 1.0 is the default look.
  @Published var barScale: Double {
    didSet { UserDefaults.standard.set(barScale, forKey: Keys.barScale) }
  }

  /// After transcribing, simulate Cmd+V to paste into the frontmost app.
  @Published var pasteOnFinish: Bool {
    didSet { UserDefaults.standard.set(pasteOnFinish, forKey: Keys.pasteOnFinish) }
  }

  /// Address of the MLX whisper server to send transcription requests to.
  @Published var sttBaseUrl: String {
    didSet { UserDefaults.standard.set(sttBaseUrl, forKey: Keys.sttBaseUrl) }
  }

  /// Which MLX whisper model size to request.
  @Published var whisperModel: WhisperModel {
    didSet { UserDefaults.standard.set(whisperModel.rawValue, forKey: Keys.whisperModel) }
  }

  private init() {
    let defaults = UserDefaults.standard
    let storedScale = defaults.object(forKey: Keys.barScale) as? Double
    self.barScale = storedScale ?? 1.0
    self.pasteOnFinish =
      (defaults.object(forKey: Keys.pasteOnFinish) as? Bool) ?? true
    self.sttBaseUrl = defaults.string(forKey: Keys.sttBaseUrl) ?? defaultSttBaseUrl
    let storedModel = defaults.string(forKey: Keys.whisperModel).flatMap(WhisperModel.init(rawValue:))
    self.whisperModel = storedModel ?? .turbo
  }
}
