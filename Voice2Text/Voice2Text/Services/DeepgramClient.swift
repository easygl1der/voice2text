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
