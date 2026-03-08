import AVFoundation
import Combine

class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var recordingURL: URL?
    private var audioFile: AVAudioFile?
    private var levelTimer: Timer?

    override init() {
        super.init()
    }

    func startRecording() -> Bool {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return false }

        inputNode = audioEngine.inputNode

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("\(UUID().uuidString).m4a")
        recordingURL = audioFilename

        // Create audio format
        let format = inputNode!.outputFormat(forBus: 0)

        do {
            // Use URL directly instead of settings dictionary
            audioFile = try AVAudioFile(forWriting: audioFilename, settings: format.settings)

            inputNode?.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                do {
                    try self?.audioFile?.write(from: buffer)
                } catch {
                    print("Error writing audio: \(error)")
                }
                self?.updateAudioLevel(buffer: buffer)
            }

            try audioEngine.start()
            isRecording = true

            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }

    func stopRecording() -> URL? {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        isRecording = false

        audioFile = nil

        let url = recordingURL
        recordingURL = nil
        return url
    }

    private func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let linearLevel = max(0, min(1, (avgPower + 60) / 60))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = linearLevel
        }
    }
}
