import AppKit
import ApplicationServices
import Carbon.HIToolbox
import SwiftUI
import VoiceScribeCore

/// Plain-file trace logging. Unified logging (NSLog/os_log) redacts dynamic
/// string content as <private> for processes not launched under Xcode, so it
/// is useless for debugging an ad-hoc-signed app launched via `open`.
private let debugLogPath: String = {
  let dir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Logs/VoiceScribe", isDirectory: true)
  try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir.appendingPathComponent("voicescribe-debug.log").path
}()

func debugLog(_ message: String) {
  let line = "\(Date()) \(message)\n"
  guard let data = line.data(using: .utf8) else { return }
  if let handle = FileHandle(forWritingAtPath: debugLogPath) {
    handle.seekToEndOfFile()
    handle.write(data)
    handle.closeFile()
  } else {
    try? data.write(to: URL(fileURLWithPath: debugLogPath))
  }
}

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

  // Global hotkeys: F7, F8, F9, F10, and Option+Space as a backup since some
  // keyboards bind the F-keys to system media/brightness functions. Any of
  // these toggles start/stop recording. Registered via the Carbon Event
  // Manager (RegisterEventHotKey) rather than NSEvent global monitors,
  // because NSEvent global key monitors require Input Monitoring permission,
  // and macOS reliably refuses to grant that to ad-hoc-signed dev builds (no
  // stable Team ID for TCC to key the grant to — confirmed via TCC's own
  // access logs during development). Carbon hotkeys need no permission at
  // all and work the moment the process registers them.
  //
  // Escape is registered only while recording is in progress (and
  // unregistered as soon as it stops) so it can cancel/stop the recording
  // without swallowing every app's normal Escape behavior the rest of the
  // time.
  private static let hotkeySignature: OSType = 0x7673_6372  // 'vscr'
  private static let hotkeyIdEscape: UInt32 = 100
  private var hotKeyRefs: [EventHotKeyRef?] = []
  private var escapeHotKeyRef: EventHotKeyRef?
  private var hotkeyWindow: NSWindow?

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

    installHotkey()
    checkAccessibilityTrust()
  }

  /// Ad-hoc-signed builds (see build-app.sh) have no stable Team ID, so
  /// System Settings' Accessibility grant is keyed to the exact binary hash
  /// and commonly goes stale after a rebuild even though the checkbox still
  /// looks enabled. Prompting here surfaces that immediately instead of
  /// pasteToActiveWindow silently no-oping later.
  private func checkAccessibilityTrust() {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    let trusted = AXIsProcessTrustedWithOptions(options)
    debugLog("accessibility trust at launch: \(trusted)")
  }

  private func installHotkey() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(
      GetApplicationEventTarget(), hotKeyEventHandler, 1, &eventType,
      Unmanaged.passUnretained(self).toOpaque(), nil)

    registerHotkey(id: 1, keyCode: UInt32(kVK_F7), modifiers: 0)
    registerHotkey(id: 2, keyCode: UInt32(kVK_F8), modifiers: 0)
    registerHotkey(id: 3, keyCode: UInt32(kVK_F9), modifiers: 0)
    registerHotkey(id: 4, keyCode: UInt32(kVK_F10), modifiers: 0)
    registerHotkey(id: 5, keyCode: UInt32(kVK_Space), modifiers: UInt32(optionKey))
  }

  private func registerHotkey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
    var ref: EventHotKeyRef?
    let hotkeyID = EventHotKeyID(signature: Self.hotkeySignature, id: id)
    let status = RegisterEventHotKey(
      keyCode, modifiers, hotkeyID, GetApplicationEventTarget(), 0, &ref)
    if status != noErr {
      debugLog("failed to register global hotkey \(id) (status \(status))")
    } else {
      hotKeyRefs.append(ref)
    }
  }

  private func registerEscapeHotkey() {
    guard escapeHotKeyRef == nil else { return }
    let hotkeyID = EventHotKeyID(signature: Self.hotkeySignature, id: Self.hotkeyIdEscape)
    var ref: EventHotKeyRef?
    let status = RegisterEventHotKey(
      UInt32(kVK_Escape), 0, hotkeyID, GetApplicationEventTarget(), 0, &ref)
    if status != noErr {
      debugLog("failed to register escape hotkey (status \(status))")
    } else {
      escapeHotKeyRef = ref
    }
  }

  private func unregisterEscapeHotkey() {
    guard let ref = escapeHotKeyRef else { return }
    UnregisterEventHotKey(ref)
    escapeHotKeyRef = nil
  }

  fileprivate func hotkeyPressed(id: UInt32) {
    debugLog("hotkeyPressed id=\(id) isRecording=\(isRecording)")
    if id == Self.hotkeyIdEscape {
      guard isRecording else { return }
      stopAndTranscribe(silent: true)
      return
    }
    isRecording ? stopAndTranscribe(silent: true) : startHotkeyRecording()
  }

  private func startHotkeyRecording() {
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
    registerEscapeHotkey()
    showHotkeyWindow()
  }

  private func showHotkeyWindow() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 220, height: 100),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.contentView = NSHostingView(
      rootView: WaveformView(model: waveformModel, settings: settings).padding())
    window.level = .floating
    window.isOpaque = false
    window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
    window.hasShadow = true
    window.isReleasedWhenClosed = false
    window.collectionBehavior = [.canJoinAllSpaces, .stationary]

    if let screen = NSScreen.main {
      let x = screen.frame.midX - window.frame.width / 2
      let y = screen.frame.minY + 80
      window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    window.orderFrontRegardless()
    hotkeyWindow = window
  }

  @objc private func statusItemClicked() {
    guard let event = NSApp.currentEvent else { return }
    if event.type == .rightMouseUp {
      showContextMenu()
    } else {
      debugLog("statusItemClicked isRecording=\(isRecording)")
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
    registerEscapeHotkey()

    if let button = statusItem.button {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
  }

  private func stopAndTranscribe(silent: Bool = false) {
    let pcm = recorder.stop()
    isRecording = false
    statusItem.button?.image = NSImage(
      systemSymbolName: "mic.fill", accessibilityDescription: "VoiceScribe")
    unregisterEscapeHotkey()
    popover.performClose(nil)
    hotkeyWindow?.close()
    hotkeyWindow = nil

    let wav = recorder.encodeWav(pcm: pcm)
    debugLog("stopAndTranscribe pcm=\(pcm.count) bytes wav=\(wav.count) bytes silent=\(silent)")

    Task {
      do {
        debugLog("sending transcribe request")
        let text = try await sttClient.transcribe(wav: wav)
        debugLog("transcribe succeeded, text length=\(text.count) pasteOnFinish=\(settings.pasteOnFinish)")
        copyToClipboard(text)
        debugLog("copyToClipboard called")
        if settings.pasteOnFinish {
          pasteToActiveWindow()
          debugLog("pasteToActiveWindow called")
        }
        if !silent {
          showResult(text, copiedToClipboard: true)
        }
      } catch {
        debugLog("transcribe FAILED: \(error)")
        showError("Transcription failed: \(error.localizedDescription)")
      }
    }
  }

  private func copyToClipboard(_ text: String) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
  }

  /// Simulates Cmd+V into the frontmost app. Requires Accessibility
  /// permission (System Settings → Privacy & Security → Accessibility).
  private func pasteToActiveWindow() {
    let frontApp = NSWorkspace.shared.frontmostApplication
    debugLog(
      "pasteToActiveWindow: frontmost=\(frontApp?.localizedName ?? "nil") "
        + "bundleID=\(frontApp?.bundleIdentifier ?? "nil") trusted=\(AXIsProcessTrusted())")
    guard let source = CGEventSource(stateID: .hidSystemState) else { return }
    let vKeyCode: CGKeyCode = 9  // 'v'

    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
    keyDown?.flags = .maskCommand
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
    keyUp?.flags = .maskCommand

    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
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

/// Carbon event handlers must be plain C function pointers (no captures), so
/// the AppDelegate instance is threaded through via the userData pointer set
/// in InstallEventHandler.
private func hotKeyEventHandler(
  nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let userData, let event else { return noErr }
  var hotKeyID = EventHotKeyID()
  let status = GetEventParameter(
    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
  guard status == noErr else { return noErr }
  let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
  Task { @MainActor in
    delegate.hotkeyPressed(id: hotKeyID.id)
  }
  return noErr
}
