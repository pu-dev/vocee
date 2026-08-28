import AppKit
import Foundation
import VoceeCore

func eprint(_ message: String) {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
}

func copyToClipboard(_ text: String) {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  pasteboard.setString(text, forType: .string)
}

/// Simulates Cmd+V into the frontmost app. Requires Accessibility permission
/// (System Settings → Privacy & Security → Accessibility) for the terminal
/// or binary running this.
func pasteToActiveWindow() {
  guard let source = CGEventSource(stateID: .hidSystemState) else { return }
  let vKeyCode: CGKeyCode = 9 // 'v'

  let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
  keyDown?.flags = .maskCommand
  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
  keyUp?.flags = .maskCommand

  keyDown?.post(tap: .cghidEventTap)
  keyUp?.post(tap: .cghidEventTap)
}

let shouldPaste = CommandLine.arguments.dropFirst().contains { $0 == "-p" || $0 == "--paste" }

let sttClient = SttClient.fromEnvironment()

let recorder = AudioRecorder()

func renderLevel(_ level: Float) {
  let width = 30
  let filled = min(width, Int(level * Float(width)))
  let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
  print("\r🎙  [\(bar)]  recording… press Enter to stop", terminator: "")
  fflush(stdout)
}

recorder.onLevel = { level in
  renderLevel(level)
}

func stopAndTranscribe() -> Never {
  let pcm = recorder.stop()
  print("\nTranscribing…")

  let wav = recorder.encodeWav(pcm: pcm)

  let semaphore = DispatchSemaphore(value: 0)
  var exitCode: Int32 = 0

  Task {
    do {
      let text = try await sttClient.transcribe(wav: wav)
      copyToClipboard(text)
      print(text)
      eprint("\n(copied to clipboard)")
      if shouldPaste {
        pasteToActiveWindow()
        eprint("(pasted to active window)")
      }
    } catch {
      eprint("Transcription failed: \(error.localizedDescription)")
      exitCode = 1
    }
    semaphore.signal()
  }
  semaphore.wait()
  exit(exitCode)
}

// Ctrl+C also stops and transcribes rather than dropping the recording.
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signal(SIGINT, SIG_IGN)
sigintSource.setEventHandler {
  stopAndTranscribe()
}
sigintSource.resume()

print("Vocee CLI" + (shouldPaste ? " (will paste into active window when done)" : ""))
do {
  try recorder.start()
} catch {
  eprint("Could not start recording: \(error.localizedDescription)")
  exit(1)
}
print("Recording… press Enter to stop and transcribe (Ctrl+C also works).")

DispatchQueue.global().async {
  _ = readLine()
  DispatchQueue.main.async {
    stopAndTranscribe()
  }
}

RunLoop.main.run()
