import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private var resultWindow: NSWindow?

  private let recorder = AudioRecorder()
  private let waveformModel = WaveformModel()
  private let settings = Settings.shared
  private var isRecording = false
  private var settingsWindow: NSWindow?

  private lazy var sttClient = SttClient(
    baseUrl: ProcessInfo.processInfo.environment["STT_BASE_URL"]
      ?? "http://127.0.0.1:8990/api/openai_compat",
    model: ProcessInfo.processInfo.environment["STT_MODEL"]
      ?? "mlx-community/whisper-large-v3-turbo",
    apiKey: ProcessInfo.processInfo.environment["STT_API_KEY"]
  )

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      button.image = NSImage(
        systemSymbolName: "mic.fill", accessibilityDescription: "VoiceScribe")
      button.action = #selector(statusItemClicked)
      button.target = self
      button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    popover = NSPopover()
    popover.behavior = .applicationDefined
    popover.contentSize = NSSize(width: 220, height: 120)
    popover.contentViewController = NSHostingController(
      rootView: WaveformView(model: waveformModel, settings: settings).padding())

    recorder.onLevel = { [weak self] level in
      self?.waveformModel.push(level)
    }
  }

  @objc private func statusItemClicked() {
    guard let event = NSApp.currentEvent else { return }
    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      isRecording ? stopAndTranscribe() : startRecording()
    }
  }

  private func showContextMenu() {
    let menu = NSMenu()
    menu.addItem(
      withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: "")
      .target = self
    statusItem.menu = menu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  @objc private func openSettings() {
    if let window = settingsWindow {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }
    let view = SettingsView(settings: settings)
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "VoiceScribe Settings"
    window.contentView = NSHostingView(rootView: view)
    window.center()
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow = window
  }

  private func startRecording() {
    waveformModel.reset()
    do {
      try recorder.start()
    } catch {
      showError("Could not start recording: \(error.localizedDescription)")
      return
    }
    isRecording = true
    statusItem.button?.image = NSImage(
      systemSymbolName: "waveform", accessibilityDescription: "Recording")

    if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  private func stopAndTranscribe() {
    let pcm = recorder.stop()
    isRecording = false
    statusItem.button?.image = NSImage(
      systemSymbolName: "mic.fill", accessibilityDescription: "VoiceScribe")
    popover.performClose(nil)

    let wav = recorder.encodeWav(pcm: pcm)

    Task {
      do {
        let text = try await sttClient.transcribe(wav: wav)
        if settings.copyToClipboard {
          copyToClipboard(text)
        }
        showResult(text, copiedToClipboard: settings.copyToClipboard)
      } catch {
        showError("Transcription failed: \(error.localizedDescription)")
      }
    }
  }

  private func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  private func showResult(_ text: String, copiedToClipboard: Bool) {
    let view = ResultView(text: text, copiedToClipboard: copiedToClipboard) { [weak self] in
      self?.resultWindow?.close()
    }
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 360, height: 260),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = "VoiceScribe"
    window.contentView = NSHostingView(rootView: view)
    window.center()
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    resultWindow = window
  }

  private func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "VoiceScribe"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
  }
}
