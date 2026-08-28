import Foundation
import VoceeCore

@MainActor
final class Settings: ObservableObject {
  static let shared = Settings()

  private enum Keys {
    static let barScale = "waveformBarScale"
    static let pasteOnFinish = "pasteOnFinish"
    static let sttBackend = "sttBackend"
  }

  /// Multiplier applied to each waveform bar's height. 1.0 is the default look.
  @Published var barScale: Double {
    didSet { UserDefaults.standard.set(barScale, forKey: Keys.barScale) }
  }

  /// After transcribing, simulate Cmd+V to paste into the frontmost app.
  @Published var pasteOnFinish: Bool {
    didSet { UserDefaults.standard.set(pasteOnFinish, forKey: Keys.pasteOnFinish) }
  }

  /// Which local whisper server to send transcription requests to.
  @Published var sttBackend: SttBackend {
    didSet { UserDefaults.standard.set(sttBackend.rawValue, forKey: Keys.sttBackend) }
  }

  private init() {
    let defaults = UserDefaults.standard
    let storedScale = defaults.object(forKey: Keys.barScale) as? Double
    self.barScale = storedScale ?? 1.0
    self.pasteOnFinish =
      (defaults.object(forKey: Keys.pasteOnFinish) as? Bool) ?? true
    let storedBackend = defaults.string(forKey: Keys.sttBackend).flatMap(SttBackend.init(rawValue:))
    self.sttBackend = storedBackend ?? .mlx
  }
}
