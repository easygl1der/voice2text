import SwiftUI
import Carbon

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var settingsWindow: NSWindow?
    var appState = AppState()
    var hotKeyManager = HotKeyManager()
    var transcriptionManager = TranscriptionServiceManager()
    var historyStorage = HistoryStorage()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice2Text")
        }

        // Create menu
        setupMenu()

        // Setup hotkey
        hotKeyManager.onHotKeyDown = { [weak self] in
            print("HotKey DOWN detected!")
            self?.startRecording()
            self?.refreshMenu()
        }
        hotKeyManager.onHotKeyUp = { [weak self] in
            print("HotKey UP detected!")
            self?.stopRecordingAndTranscribe()
            self?.refreshMenu()
        }
        hotKeyManager.setup()

        loadHistory()
    }

    func setupMenu() {
        let menu = NSMenu()

        // Add status at top
        let statusMenuItem = NSMenuItem(title: "Status: \(appState.status.rawValue)", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Add Settings button
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Add Quit button
        let quitItem = NSMenuItem(title: "Quit Voice2Text", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem?.menu = menu
    }

    func refreshMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupMenu()
        }
    }

    @objc func openSettings() {
        showSettings()
    }

    func startRecording() {
        print("startRecording called!")
        guard !appState.audioRecorder.isRecording else { return }
        appState.status = .recording
        let started = appState.audioRecorder.startRecording()
        print("Recording started: \(started)")
    }

    func stopRecordingAndTranscribe() {
        guard appState.audioRecorder.isRecording else { return }

        if let audioURL = appState.audioRecorder.stopRecording() {
            appState.status = .transcribing
            Task {
                do {
                    let text = try await transcriptionManager.transcribe(
                        audioURL: audioURL,
                        service: appState.selectedService,
                        language: appState.selectedLanguage,
                        apiKey: appState.apiKey
                    )

                    // Save to history
                    let transcript = Transcript(
                        text: text,
                        service: appState.selectedService.rawValue,
                        language: appState.selectedLanguage
                    )
                    appState.transcripts.append(transcript)
                    saveTranscript(transcript)

                    // Paste to cursor
                    pasteToCursor(text: text)

                    appState.status = .ready
                } catch {
                    appState.lastError = error.localizedDescription
                    appState.status = .error
                }
            }
        }
    }

    func pasteToCursor(text: String) {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        // Restore previous clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    func loadHistory() {
        appState.transcripts = historyStorage.loadAll()
    }

    func saveTranscript(_ transcript: Transcript) {
        historyStorage.save(transcript)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Voice2Text Settings"
            window.contentView = NSHostingView(rootView: SettingsView(appState: appState))
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
