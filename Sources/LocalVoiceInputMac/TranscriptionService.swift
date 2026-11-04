import Foundation
import VoiceInputCore
import WhisperKit

actor TranscriptionService {
    private var engine: WhisperKit?
    private let merger = TranscriptMerger()
    private let punctuator = TranscriptPunctuator()
    private let hallucinations = HallucinationFilter()

    func transcribe(file: URL) async throws -> String {
        let engine = try await loadEngine()
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "zh",
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: false,
            wordTimestamps: true
        )
        let results: [TranscriptionResult] = try await engine.transcribe(
            audioPath: file.path,
            decodeOptions: options
        )
        let punctuatedResults = results.map { result in
            let words = result.allWords.map {
                TimedTranscriptWord(text: $0.word, start: $0.start, end: $0.end)
            }
            // Each 30-second window can end in its own made-up sign-off.
            return hallucinations.clean(punctuator.punctuate(words: words, fallbackText: result.text))
        }
        return merger.merge(punctuatedResults).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadEngine() async throws -> WhisperKit {
        if let engine { return engine }

        let config = WhisperKitConfig(
            model: "openai_whisper-large-v3-v20240930_626MB",
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: true,
            useBackgroundDownloadSession: false
        )
        let newEngine = try await WhisperKit(config)
        engine = newEngine
        return newEngine
    }
}
