# Voice2Text Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个 macOS 菜单栏语音输入应用，支持全局快捷键录音、多种在线 API 转写、自动粘贴到光标位置、保存历史记录

**Architecture:** 菜单栏 App (Menu Bar App)，使用 SwiftUI + AppKit 混合架构。音频录制用 AVFoundation，网络请求用 URLSession，快捷键用 HotKey 库，存储用 SQLite

**Tech Stack:** SwiftUI, AppKit, AVFoundation, URLSession, SQLite.swift, HotKey

---

## Task 1: 项目初始化与菜单栏基础

**Files:**
- Create: `Voice2Text/project.yml` - XcodeGen 配置
- Create: `Voice2Text/Voice2Text/App.swift` - App 入口
- Create: `Voice2Text/Voice2Text/Voice2TextApp.swift` - 主应用
- Create: `Voice2Text/Voice2Text/Info.plist` - 应用配置

**Step 1: 创建项目目录和 XcodeGen 配置**

```bash
mkdir -p Voice2Text/Voice2Text/Resources
cd Voice2Text

cat > project.yml << 'EOF'
name: Voice2Text
options:
  bundleIdPrefix: com.voice2text
  deploymentTarget:
    macOS: "13.0"
  xcodeVersion: "15.0"

settings:
  base:
    SWIFT_VERSION: "5.9"
    MACOSX_DEPLOYMENT_TARGET: "13.0"

targets:
  Voice2Text:
    type: application
    platform: macOS
    sources:
      - Voice2Text
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.voice2text.app
        INFOPLIST_FILE: Voice2Text/Info.plist
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGNING_REQUIRED: NO
        ENABLE_HARDENED_RUNTIME: NO
        COMBINE_HIDPI_IMAGES: YES
    entitlements:
      path: Voice2Text/Voice2Text.entitlements
      properties:
        com.apple.security.app-sandbox: false
        com.apple.security.device.audio-input: true
```

**Step 2: 创建 Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMainStoryboardFile</key>
    <string></string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Voice2Text needs microphone access to record your voice for transcription.</string>
</dict>
</plist>
```

**Step 3: 创建 entitlements 文件**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.device.audio-input</key>
    <true/>
</dict>
</plist>
```

**Step 4: 创建 App.swift**

```swift
import SwiftUI

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

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice2Text")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "About Voice2Text", action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
```

**Step 5: 生成 Xcode 项目并验证**

```bash
xcodegen generate
```

Expected: 生成 `Voice2Text.xcodeproj`

**Step 6: Commit**

```bash
git init
git add .
git commit -m "feat: 初始化 Voice2Text 项目基础结构"
```

---

## Task 2: 菜单栏界面完善

**Files:**
- Create: `Voice2Text/Voice2Text/Views/MenuBarView.swift`
- Create: `Voice2Text/Voice2Text/Views/SettingsView.swift`
- Create: `Voice2Text/Voice2Text/Models/AppState.swift`
- Modify: `Voice2Text/Voice2Text/AppDelegate.swift`

**Step 1: 创建 AppState 模型**

```swift
import SwiftUI
import Combine

enum TranscriptionService: String, CaseIterable, Identifiable {
    case deepgram = "Deepgram"
    case assemblyAI = "AssemblyAI"
    case mistral = "Mistral"
    case localWhisper = "Local Whisper"

    var id: String { rawValue }
}

enum AppStatus: String {
    case ready = "Ready"
    case recording = "Recording"
    case transcribing = "Transcribing"
    case error = "Error"
}

class AppState: ObservableObject {
    @Published var status: AppStatus = .ready
    @Published var selectedService: TranscriptionService = .deepgram
    @Published var selectedLanguage: String = "Chinese"
    @Published var apiKey: String = ""
    @Published var transcripts: [Transcript] = []

    let languages = ["Chinese", "English", "Japanese", "Korean", "Spanish", "French", "German"]
}

struct Transcript: Identifiable, Codable {
    let id: UUID
    let text: String
    let timestamp: Date
    let service: String
    let language: String

    init(text: String, service: String, language: String) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.service = service
        self.language = language
    }
}
```

**Step 2: 创建 MenuBarView**

```swift
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState
    let onRecord: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(appState.status.rawValue)
                    .font(.system(size: 13))
            }

            Divider()

            // API Selection
            Picker("API", selection: $appState.selectedService) {
                ForEach(TranscriptionService.allCases) { service in
                    Text(service.rawValue).tag(service)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            // Language Selection
            Picker("Language", selection: $appState.selectedLanguage) {
                ForEach(appState.languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 180)

            Divider()

            // History
            Button(action: {}) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("History")
                }
            }
            .buttonStyle(.plain)

            Divider()

            // Quit
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 220)
    }

    var statusColor: Color {
        switch appState.status {
        case .ready: return .green
        case .recording: return .red
        case .transcribing: return .orange
        case .error: return .gray
        }
    }
}
```

**Step 3: 更新 AppDelegate 使用 MenuBarView**

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var appState = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice2Text")
            button.action = #selector(toggleMenu)
            button.target = self
        }

        updateMenu()
    }

    @objc func toggleMenu() {
        if let menu = statusItem?.menu {
            statusItem?.button?.performClick(nil)
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        // Status
        let statusItem = NSMenuItem()
        let statusView = MenuBarView(appState: appState, onRecord: {}, onStop: {})
        statusItem.view = NSHostingView(rootView: statusView)
        menu.addItem(statusItem)

        self.statusItem?.menu = menu
    }
}
```

**Step 4: Commit**

```bash
git add .
git commit -m "feat: 添加菜单栏界面和状态管理"
```

---

## Task 3: 音频录制服务

**Files:**
- Create: `Voice2Text/Voice2Text/Services/AudioRecorder.swift`

**Step 1: 创建 AudioRecorder 服务**

```swift
import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    override init() {
        super.init()
    }

    func startRecording() -> Bool {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return false
        }

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = audioFilename

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            isRecording = true

            // Start level monitoring
            levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.updateAudioLevel()
            }

            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }

    func stopRecording() -> URL? {
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()
        isRecording = false

        let url = recordingURL
        recordingURL = nil
        return url
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // Convert dB to linear scale (0-1)
        let linearLevel = max(0, min(1, (level + 60) / 60))
        audioLevel = linearLevel
    }
}
```

**Step 2: 更新 AppState 添加 AudioRecorder**

```swift
class AppState: ObservableObject {
    // ... existing properties
    var audioRecorder = AudioRecorder()
}
```

**Step 3: Commit**

```bash
git add .
git commit -m "feat: 添加音频录制服务"
```

---

## Task 4: API 转写服务

**Files:**
- Create: `Voice2Text/Voice2Text/Services/TranscriptionService.swift`
- Create: `Voice2Text/Voice2Text/Services/DeepgramClient.swift`
- Create: `Voice2Text/Voice2Text/Services/AssemblyAIClient.swift`
- Create: `Voice2Text/Voice2Text/Services/MistralClient.swift`

**Step 1: 创建 TranscriptionService 协议和工厂**

```swift
import Foundation

protocol TranscriptionClient {
    func transcribe(audioURL: URL, language: String, apiKey: String) async throws -> String
}

enum TranscriptionError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case serverError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "API key not configured"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error \(code): \(message)"
        }
    }
}

class TranscriptionServiceManager: ObservableObject {
    @Published var lastError: String?

    func transcribe(audioURL: URL, service: TranscriptionService, language: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.noAPIKey
        }

        let client: TranscriptionClient

        switch service {
        case .deepgram:
            client = DeepgramClient()
        case .assemblyAI:
            client = AssemblyAIClient()
        case .mistral:
            client = MistralClient()
        case .localWhisper:
            // Will implement later
            throw TranscriptionError.noAPIKey
        }

        return try await client.transcribe(audioURL: audioURL, language: languageCode(for: language), apiKey: apiKey)
    }

    private func languageCode(for language: String) -> String {
        switch language {
        case "Chinese": return "zh"
        case "English": return "en"
        case "Japanese": return "ja"
        case "Korean": return "ko"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        default: return "en"
        }
    }
}
```

**Step 2: 创建 DeepgramClient**

```swift
import Foundation

class DeepgramClient: TranscriptionClient {
    func transcribe(audioURL: URL, language: String, apiKey: String) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)
        let base64Audio = audioData.base64EncodedString()

        let url = URL(string: "https://api.deepgram.com/v1/listen")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "audio": ["url": "data:audio/m4a;base64,\(base64Audio)"],
            "model": "nova-2",
            "language": language,
            "smart_format": true,
            "punctuate": true
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.serverError(httpResponse.statusCode, errorMessage)
        }

        let result = try JSONDecoder().decode(DeepgramResponse.self, from: data)

        guard let transcript = result.results.channels.first?.alternatives.first?.transcript else {
            throw TranscriptionError.invalidResponse
        }

        return transcript
    }
}

struct DeepgramResponse: Codable {
    let results: DeepgramResults
}

struct DeepgramResults: Codable {
    let channels: [DeepgramChannel]
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
}
```

**Step 3: 创建 AssemblyAIClient**

```swift
import Foundation

class AssemblyAIClient: TranscriptionClient {
    func transcribe(audioURL: URL, language: String, apiKey: String) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        // Step 1: Upload audio
        let uploadURL = URL(string: "https://api.assemblyai.com/v2/upload")!
        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue(apiKey, forHTTPHeaderField: "authorization")
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpBody = audioData

        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)

        guard let uploadHTTPResponse = uploadResponse as? HTTPURLResponse,
              uploadHTTPResponse.statusCode == 200 else {
            throw TranscriptionError.invalidResponse
        }

        let uploadResult = try JSONDecoder().decode(AssemblyAIUploadResponse.self, from: uploadData)

        // Step 2: Request transcription
        let transcriptURL = URL(string: "https://api.assemblyai.com/v2/transcript")!
        var transcriptRequest = URLRequest(url: transcriptURL)
        transcriptRequest.httpMethod = "POST"
        transcriptRequest.setValue(apiKey, forHTTPHeaderField: "authorization")
        transcriptRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let transcriptBody: [String: Any] = [
            "audio_url": uploadResult.upload_url,
            "language_code": assemblyAILanguageCode(language)
        ]

        transcriptRequest.httpBody = try JSONSerialization.data(withJSONObject: transcriptBody)

        let (transcriptResponseData, _) = try await URLSession.shared.data(for: transcriptRequest)
        let transcriptRequestResult = try JSONDecoder().decode(AssemblyAITranscriptRequest.self, from: transcriptResponseData)

        // Step 3: Poll for result
        let resultURL = URL(string: "https://api.assemblyai.com/v2/transcript/\(transcriptRequestResult.id)")!

        while true {
            var resultRequest = URLRequest(url: resultURL)
            resultRequest.setValue(apiKey, forHTTPHeaderField: "authorization")

            let (resultData, resultResponse) = try await URLSession.shared.data(for: resultRequest)
            let result = try JSONDecoder().decode(AssemblyAITranscriptResult.self, from: resultData)

            if result.status == "completed" {
                return result.text ?? ""
            } else if result.status == "error" {
                throw TranscriptionError.serverError(500, result.error ?? "Transcription failed")
            }

            try await Task.sleep(nanoseconds: 1_000_000_000) // Wait 1 second
        }
    }

    private func assemblyAILanguageCode(_ language: String) -> String {
        switch language {
        case "Chinese": return "zh"
        case "English": return "en"
        case "Japanese": return "ja"
        case "Korean": return "ko"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        default: return "en"
        }
    }
}

struct AssemblyAIUploadResponse: Codable {
    let upload_url: String
}

struct AssemblyAITranscriptRequest: Codable {
    let id: String
}

struct AssemblyAITranscriptResult: Codable {
    let status: String
    let text: String?
    let error: String?
}
```

**Step 4: 创建 MistralClient**

```swift
import Foundation

class MistralClient: TranscriptionClient {
    func transcribe(audioURL: URL, language: String, apiKey: String) async throws -> String {
        let audioData = try Data(contentsOf: audioURL)

        let url = URL(string: "https://api.mistral.ai/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(mistralLanguageCode(language))\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranscriptionError.serverError(httpResponse.statusCode, errorMessage)
        }

        let result = try JSONDecoder().decode(MistralResponse.self, from: data)
        return result.text
    }

    private func mistralLanguageCode(_ language: String) -> String {
        switch language {
        case "Chinese": return "zh"
        case "English": return "en"
        case "Japanese": return "ja"
        case "Korean": return "ko"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        default: return "en"
        }
    }
}

struct MistralResponse: Codable {
    let text: String
}
```

**Step 5: Commit**

```bash
git add .
git commit -m "feat: 添加 Deepgram、AssemblyAI、Mistral API 客户端"
```

---

## Task 5: 全局快捷键管理

**Files:**
- Create: `Voice2Text/Voice2Text/Services/HotKeyManager.swift`
- Modify: `Voice2Text/Voice2Text/Services/AudioRecorder.swift`
- Modify: `Voice2Text/Voice2Text/AppDelegate.swift`

**Step 1: 添加 HotKey 依赖**

在 project.yml 中添加 SPM 依赖：

```yaml
packages:
  HotKey:
    url: https://github.com/soffes/HotKey
    from: "0.2.0"
```

更新 target 添加依赖：

```yaml
targets:
  Voice2Text:
    dependencies:
      - package: HotKey
```

重新生成项目：
```bash
xcodegen generate
```

**Step 2: 创建 HotKeyManager**

```swift
import Foundation
import HotKey
import Carbon

class HotKeyManager: ObservableObject {
    @Published var isEnabled = false

    var onHotKeyDown: (() -> Void)?
    var onHotKeyUp: (() -> Void)?

    private var hotKey: HotKey?
    private var isRecording = false

    func setup(key: Key = .v, modifiers: NSEvent.ModifierFlags = .option) {
        hotKey = HotKey(key: key, modifiers: modifiers)

        hotKey?.keyDownHandler = { [weak self] in
            guard let self = self else { return }
            self.isRecording = true
            self.onHotKeyDown?()
        }

        // Note: HotKey library doesn't have keyUp, we'll handle this differently
        isEnabled = true
    }

    func stop() {
        hotKey = nil
        isEnabled = false
    }

    var recordingState: Bool {
        get { isRecording }
        set { isRecording = newValue }
    }
}
```

**Step 3: 更新 AppDelegate 集成快捷键**

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var appState = AppState()
    var hotKeyManager = HotKeyManager()
    var transcriptionManager = TranscriptionServiceManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Voice2Text")
        }

        // Setup hotkey
        hotKeyManager.onHotKeyDown = { [weak self] in
            self?.startRecording()
        }
        hotKeyManager.setup()

        updateMenu()
    }

    func startRecording() {
        guard !appState.audioRecorder.isRecording else { return }
        appState.status = .recording
        _ = appState.audioRecorder.startRecording()
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

        // Optionally restore previous clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let previous = previousContents {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }
}
```

**Step 4: 添加全局键盘监听**

由于 HotKey 库不直接支持 keyUp，我们需要用 NSEvent 添加全局监听：

```swift
func setupGlobalKeyListener() {
    NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] event in
        // Check if Option key was released
        if event.modifierFlags.contains(.option) {
            self?.stopRecordingAndTranscribe()
        }
    }

    NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
        if event.modifierFlags.contains(.option) {
            self?.stopRecordingAndTranscribe()
        }
        return event
    }
}
```

**Step 5: Commit**

```bash
git add .
git commit -m "feat: 添加全局快捷键支持"
```

---

## Task 6: 历史记录存储

**Files:**
- Create: `Voice2Text/Voice2Text/Services/HistoryStorage.swift`
- Modify: `Voice2Text/Voice2Text/AppDelegate.swift`

**Step 1: 添加 SQLite.swift 依赖**

更新 project.yml:

```yaml
packages:
  SQLite:
    url: https://github.com/stephencelis/SQLite.swift
    from: "0.15.0"
```

更新 target dependencies:

```yaml
dependencies:
  - package: HotKey
  - package: SQLite
```

重新生成项目：
```bash
xcodegen generate
```

**Step 2: 创建 HistoryStorage**

```swift
import Foundation
import SQLite

class HistoryStorage {
    private var db: Connection?
    private let transcripts = Table("transcripts")

    // Columns
    private let id = SQLite.Expression<String>("id")
    private let text = SQLite.Expression<String>("text")
    private let timestamp = SQLite.Expression<Date>("timestamp")
    private let service = SQLite.Expression<String>("service")
    private let language = SQLite.Expression<String>("language")

    init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dbPath = documentsPath.appendingPathComponent("voice2text.sqlite3").path
            db = try Connection(dbPath)

            try db?.run(transcripts.create(ifNotExists: true) { t in
                t.column(id, primaryKey: true)
                t.column(text)
                t.column(timestamp)
                t.column(service)
                t.column(language)
            })
        } catch {
            print("Database setup error: \(error)")
        }
    }

    func save(_ transcript: Transcript) {
        do {
            let insert = transcripts.insert(
                id <- transcript.id.uuidString,
                text <- transcript.text,
                timestamp <- transcript.timestamp,
                service <- transcript.service,
                language <- transcript.language
            )
            try db?.run(insert)
        } catch {
            print("Save error: \(error)")
        }
    }

    func loadAll() -> [Transcript] {
        var results: [Transcript] = []

        do {
            let query = transcripts.order(timestamp.desc)
            for row in try db?.prepare(query) ?? [] {
                if let uuid = UUID(uuidString: row[id]) {
                    let transcript = Transcript(
                        text: row[text],
                        service: row[service],
                        language: row[language]
                    )
                    results.append(transcript)
                }
            }
        } catch {
            print("Load error: \(error)")
        }

        return results
    }

    func delete(id transcriptId: UUID) {
        do {
            let transcript = transcripts.filter(id == transcriptId.uuidString)
            try db?.run(transcript.delete())
        } catch {
            print("Delete error: \(error)")
        }
    }

    func search(query: String) -> [Transcript] {
        var results: [Transcript] = []

        do {
            let searchQuery = transcripts.filter(text.like("%\(query)%")).order(timestamp.desc)
            for row in try db?.prepare(searchQuery) ?? [] {
                let transcript = Transcript(
                    text: row[text],
                    service: row[service],
                    language: row[language]
                )
                results.append(transcript)
            }
        } catch {
            print("Search error: \(error)")
        }

        return results
    }
}
```

**Step 3: 集成到 AppDelegate**

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    // ... existing properties
    var historyStorage = HistoryStorage()

    // 在保存 transcript 后添加
    func saveTranscript(_ transcript: Transcript) {
        historyStorage.save(transcript)
    }

    // 在应用启动时加载历史
    func loadHistory() {
        appState.transcripts = historyStorage.loadAll()
    }
}
```

**Step 4: Commit**

```bash
git add .
git commit -m "feat: 添加历史记录存储功能"
```

---

## Task 7: 设置界面

**Files:**
- Create: `Voice2Text/Voice2Text/Views/SettingsView.swift`
- Modify: `Voice2Text/Voice2Text/AppDelegate.swift`

**Step 1: 创建设置视图**

```swift
import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var showingAPIKeyField = false

    var body: some View {
        TabView {
            // General Tab
            Form {
                Section("Hotkey") {
                    Text("Current: Option + V")
                        .foregroundColor(.secondary)
                }

                Section("Language") {
                    Picker("Default Language", selection: $appState.selectedLanguage) {
                        ForEach(appState.languages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                }
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // API Tab
            Form {
                Section("Transcription Service") {
                    Picker("Service", selection: $appState.selectedService) {
                        ForEach(TranscriptionService.allCases) { service in
                            Text(service.rawValue).tag(service)
                        }
                    }
                }

                Section("API Key") {
                    if showingAPIKeyField {
                        SecureField("Enter API Key", text: $appState.apiKey)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        HStack {
                            Text(appState.apiKey.isEmpty ? "Not Set" : "••••••••")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Edit") {
                                showingAPIKeyField = true
                            }
                        }
                    }
                }

                Section {
                    Link("Get Deepgram API Key", destination: URL(string: "https://deepgram.com")!)
                    Link("Get AssemblyAI API Key", destination: URL(string: "https://assemblyai.com")!)
                    Link("Get Mistral API Key", destination: URL(string: "https://mistral.ai")!)
                }
            }
            .tabItem {
                Label("API", systemImage: "key")
            }

            // History Tab
            HistoryListView(appState: appState)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .frame(width: 450, height: 350)
    }
}

struct HistoryListView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""

    var filteredTranscripts: [Transcript] {
        if searchText.isEmpty {
            return appState.transcripts
        }
        return appState.transcripts.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack {
            if appState.transcripts.isEmpty {
                Text("No transcripts yet")
                    .foregroundColor(.secondary)
            } else {
                List(filteredTranscripts) { transcript in
                    VStack(alignment: .leading) {
                        Text(transcript.text)
                            .lineLimit(2)
                        HStack {
                            Text(transcript.service)
                                .font(.caption)
                            Text(transcript.language)
                                .font(.caption)
                            Spacer()
                            Text(transcript.timestamp, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
```

**Step 2: 添加设置入口到菜单栏**

在 AppDelegate 中添加：

```swift
func showSettings() {
    let settingsWindow = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    settingsWindow.title = "Voice2Text Settings"
    settingsWindow.contentView = NSHostingView(rootView: SettingsView(appState: appState))
    settingsWindow.center()
    settingsWindow.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

**Step 3: Commit**

```bash
git add .
git commit -m "feat: 添加设置界面"
```

---

## Task 8: 本地 Whisper 支持（备选）

**Files:**
- Create: `Voice2Text/Voice2Text/Services/LocalWhisperClient.swift`

**Step 1: 添加 whisper.cpp 绑定或使用 python 脚本**

由于 Swift 直接集成 whisper.cpp 比较复杂，可以使用 Python 脚本作为桥接：

```swift
class LocalWhisperClient: TranscriptionClient {
    func transcribe(audioURL: URL, language: String, apiKey: String) async throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import whisper
            import sys

            model = whisper.load_model("base")
            result = model.transcribe("\(audioURL.path)", language="\(languageCode(language))")
            print(result["text"])
            """
        ]
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func languageCode(_ language: String) -> String {
        switch language {
        case "Chinese": return "zh"
        case "English": return "en"
        case "Japanese": return "ja"
        case "Korean": return "ko"
        default: return "en"
        }
    }
}
```

**Step 2: Commit**

```bash
git add .
git commit -m "feat: 添加本地 Whisper 支持"
```

---

## Summary

**Total Tasks: 8**

| Task | Component | Estimated Time |
|------|-----------|----------------|
| 1 | 项目初始化 | 15 min |
| 2 | 菜单栏界面 | 20 min |
| 3 | 音频录制 | 15 min |
| 4 | API 服务 | 30 min |
| 5 | 全局快捷键 | 20 min |
| 6 | 历史记录 | 15 min |
| 7 | 设置界面 | 15 min |
| 8 | 本地模型 | 20 min |

---

## Agents 分工建议

可以并行执行的任务：
- **Task 1** (项目初始化) - 需要先完成
- **Task 2** (菜单栏) + **Task 3** (音频录制) - 可以并行
- **Task 4** (API 服务) - 独立，可以单独分配
- **Task 5** (快捷键) - 依赖 Task 3
- **Task 6** (历史记录) - 独立
- **Task 7** (设置界面) - 依赖 Task 2
- **Task 8** (本地模型) - 可选后续

**推荐分工方式：**
1. **Agent 1**: Task 1 → Task 2 → Task 3 (基础架构)
2. **Agent 2**: Task 4 (API 服务) - 核心功能
3. **Agent 3**: Task 5 → Task 6 → Task 7 (集成与UI)
4. **Task 8**: 可选，优先级低
