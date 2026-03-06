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

            let (resultData, _) = try await URLSession.shared.data(for: resultRequest)
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
