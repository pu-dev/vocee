import Foundation

@MainActor
final class Settings: ObservableObject {
  static let shared = Settings()

  private enum Keys {
    static let barScale = "waveformBarScale"
    static let pasteOnFinish = "pasteOnFinish"
  }

  /// Multiplier applied to each waveform bar's height. 1.0 is the default look.
  @Published var barScale: Double {
    didSet { UserDefaults.standard.set(barScale, forKey: Keys.barScale) }
  }

  /// After transcribing, simulate Cmd+V to paste into the frontmost app.
  @Published var pasteOnFinish: Bool {
    didSet { UserDefaults.standard.set(pasteOnFinish, forKey: Keys.pasteOnFinish) }
  }

  private init() {
    let defaults = UserDefaults.standard
    let storedScale = defaults.object(forKey: Keys.barScale) as? Double
    self.barScale = storedScale ?? 1.0
    self.pasteOnFinish =
      (defaults.object(forKey: Keys.pasteOnFinish) as? Bool) ?? false
  }
}
