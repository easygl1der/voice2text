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
