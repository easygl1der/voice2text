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
    @Published var lastError: String = ""
    var audioRecorder = AudioRecorder()

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
