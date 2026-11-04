import AVFoundation
import Foundation

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "沒有麥克風權限，請到「系統設定 → 隱私權與安全性 → 麥克風」開啟。"
        case .couldNotStart:
            return "無法開始錄音。"
        }
    }
}

@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var currentFile: URL?

    override init() {
        super.init()
        removeStaleTemporaryRecordings()
    }

    func start() async throws {
        guard await requestPermission() else {
            throw AudioRecorderError.permissionDenied
        }

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("local-voice-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let recorder = try AVAudioRecorder(url: file, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw AudioRecorderError.couldNotStart
        }

        self.recorder = recorder
        currentFile = file
    }

    /// Current loudness from 0 (silence) to 1, for the on-screen indicator.
    func level() -> Float {
        guard let recorder, recorder.isRecording else { return 0 }
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        return max(0, min(1, (decibels + 50) / 50))
    }

    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return currentFile
    }

    func discardCurrentFile() {
        recorder?.stop()
        recorder = nil
        if let currentFile {
            try? FileManager.default.removeItem(at: currentFile)
        }
        currentFile = nil
    }

    private func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    private func removeStaleTemporaryRecordings() {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: temporaryDirectory,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files where file.lastPathComponent.hasPrefix("local-voice-") && file.pathExtension == "wav" {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
