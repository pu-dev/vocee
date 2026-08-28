import SwiftUI

struct ResultView: View {
  let text: String
  let copiedToClipboard: Bool
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(copiedToClipboard ? "Transcript copied to clipboard" : "Transcript")
        .font(.headline)
      ScrollView {
        Text(text)
          .font(.body)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 200)
      HStack {
        Spacer()
        Button("Close") { onDismiss() }
          .keyboardShortcut(.cancelAction)
      }
    }
    .padding(16)
    .frame(width: 360)
  }
}
