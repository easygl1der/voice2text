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
