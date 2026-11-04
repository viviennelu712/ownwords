import Foundation
import VoiceInputCore
import WhisperKit

guard (2...4).contains(CommandLine.arguments.count) else {
    FileHandle.standardError.write(Data("Usage: VoiceInputBenchmark <audio-file> [model] [prompt]\n".utf8))
    exit(2)
}

let audioPath = CommandLine.arguments[1]
let modelName = CommandLine.arguments.count >= 3 && !CommandLine.arguments[2].isEmpty
    ? CommandLine.arguments[2]
    : "openai_whisper-large-v3-v20240930_626MB"
let promptText = CommandLine.arguments.count == 4 ? CommandLine.arguments[3] : ""
let startedAt = Date()
let config = WhisperKitConfig(
    model: modelName,
    verbose: false,
    logLevel: .error,
    prewarm: true,
    load: true,
    download: true,
    useBackgroundDownloadSession: false
)
let engine = try await WhisperKit(config)
let loadedAt = Date()
let promptTokens: [Int]? = promptText.isEmpty ? nil : engine.tokenizer.map { tokenizer in
    tokenizer.encode(text: " " + promptText).filter { $0 < tokenizer.specialTokens.specialTokenBegin }
}
let options = DecodingOptions(
    verbose: false,
    task: .transcribe,
    language: "zh",
    usePrefillPrompt: ProcessInfo.processInfo.environment["NO_PREFILL"] == nil,
    detectLanguage: false,
    skipSpecialTokens: true,
    withoutTimestamps: false,
    wordTimestamps: ProcessInfo.processInfo.environment["NO_WORDTS"] == nil,
    promptTokens: promptTokens
)
let results: [TranscriptionResult] = try await engine.transcribe(
    audioPath: audioPath,
    decodeOptions: options
)
let punctuator = TranscriptPunctuator()
let punctuatedResults = results.map { result in
    punctuator.punctuate(
        words: result.allWords.map {
            TimedTranscriptWord(text: $0.word, start: $0.start, end: $0.end)
        },
        fallbackText: result.text
    )
}
let merged = TranscriptMerger().merge(punctuatedResults)
let cleaned = TranscriptCleaner().clean(merged)
let completedAt = Date()

print("MODEL_LOAD_SECONDS=\(loadedAt.timeIntervalSince(startedAt))")
print("TRANSCRIBE_SECONDS=\(completedAt.timeIntervalSince(loadedAt))")
print("RESULT_COUNT=\(results.count)")
for (index, result) in results.enumerated() {
    for word in result.allWords {
        let start = String(format: "%.2f", word.start)
        let end = String(format: "%.2f", word.end)
        print("WORD[\(index)]=\(start)-\(end) \(word.word)")
    }
}
print("RAW=\(merged)")
print("CLEAN=\(cleaned)")
