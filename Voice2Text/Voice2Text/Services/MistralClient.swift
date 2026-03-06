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
