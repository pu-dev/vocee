import SwiftUI

final class WaveformModel: ObservableObject {
  @Published var levels: [Float] = Array(repeating: 0, count: 40)

  func push(_ level: Float) {
    levels.removeFirst()
    levels.append(level)
  }

  func reset() {
    levels = Array(repeating: 0, count: 40)
  }
}

struct WaveformView: View {
  @ObservedObject var model: WaveformModel
  @ObservedObject var settings: Settings

  var body: some View {
    HStack(alignment: .center, spacing: 2) {
      ForEach(Array(model.levels.enumerated()), id: \.offset) { _, level in
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.accentColor)
          .frame(width: 3, height: max(2, CGFloat(level) * 56 * CGFloat(settings.barScale)))
      }
    }
    .frame(height: 60 * CGFloat(settings.barScale))
    .animation(.linear(duration: 0.05), value: model.levels)
  }
}
