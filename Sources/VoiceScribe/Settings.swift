import Foundation

@MainActor
final class Settings: ObservableObject {
  static let shared = Settings()

  private enum Keys {
    static let barScale = "waveformBarScale"
    static let copyToClipboard = "copyToClipboard"
  }

  /// Multiplier applied to each waveform bar's height. 1.0 is the default look.
  @Published var barScale: Double {
    didSet { UserDefaults.standard.set(barScale, forKey: Keys.barScale) }
  }

  @Published var copyToClipboard: Bool {
    didSet { UserDefaults.standard.set(copyToClipboard, forKey: Keys.copyToClipboard) }
  }

  private init() {
    let defaults = UserDefaults.standard
    let storedScale = defaults.object(forKey: Keys.barScale) as? Double
    self.barScale = storedScale ?? 1.0
    self.copyToClipboard =
      (defaults.object(forKey: Keys.copyToClipboard) as? Bool) ?? true
  }
}
