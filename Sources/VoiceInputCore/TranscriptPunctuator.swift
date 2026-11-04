import Foundation

public struct TimedTranscriptWord: Sendable, Equatable {
    public let text: String
    public let start: Float
    public let end: Float

    public init(text: String, start: Float, end: Float) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// Adds stable Chinese punctuation from actual pauses in the recording instead
/// of relying only on the speech model's punctuation guesses.
public struct TranscriptPunctuator: Sendable {
    public let commaPause: Float
    public let sentencePause: Float

    public init(commaPause: Float = 0.32, sentencePause: Float = 1.3) {
        self.commaPause = commaPause
        self.sentencePause = sentencePause
    }

    public func punctuate(words: [TimedTranscriptWord], fallbackText: String) -> String {
        guard !words.isEmpty else {
            return ensureFinalPunctuation(fallbackText)
        }

        var output = ""
        var previous: TimedTranscriptWord?

        for word in words {
            let text = sanitized(word.text)
            guard !text.isEmpty else { continue }

            if let previous {
                let pause = max(0, word.start - previous.end)
                if pause >= sentencePause {
                    output = ensureSentenceBoundary(output, before: text)
                } else if pause >= commaPause {
                    output = ensureCommaBoundary(output, before: text)
                }
            }

            output += text
            previous = word
        }

        return ensureFinalPunctuation(output)
    }

    private func sanitized(_ source: String) -> String {
        source.replacingOccurrences(
            of: #"<\|[^|>]+\|>"#,
            with: "",
            options: .regularExpression
        )
    }

    private func ensureCommaBoundary(_ source: String, before next: String) -> String {
        guard !source.isEmpty,
              !endsWithAnyPunctuation(source),
              !startsWithAnyPunctuation(next)
        else { return source }

        return source + "，"
    }

    private func ensureSentenceBoundary(_ source: String, before next: String) -> String {
        guard !source.isEmpty, !startsWithAnyPunctuation(next) else { return source }

        if endsWithSentencePunctuation(source) {
            return source
        }

        if endsWithContinuationWord(source) {
            return ensureCommaBoundary(source, before: next)
        }

        if let last = source.last, softPunctuation.contains(last) {
            return String(source.dropLast()) + "。"
        }

        return source + "。"
    }

    private func endsWithContinuationWord(_ source: String) -> Bool {
        let trimmed = source.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,、；;：:"))
        )
        return continuationWords.contains { trimmed.hasSuffix($0) }
    }

    private func ensureFinalPunctuation(_ source: String) -> String {
        let result = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.unicodeScalars.contains(where: { scalar in
            (0x3400...0x4DBF).contains(scalar.value) ||
                (0x4E00...0x9FFF).contains(scalar.value) ||
                (0xF900...0xFAFF).contains(scalar.value)
        }), !endsWithAnyPunctuation(result) else {
            return result
        }

        return result + "。"
    }

    private func startsWithAnyPunctuation(_ source: String) -> Bool {
        guard let first = source.first(where: { !$0.isWhitespace }) else { return false }
        return allPunctuation.contains(first)
    }

    private func endsWithAnyPunctuation(_ source: String) -> Bool {
        guard let last = source.last(where: { !$0.isWhitespace }) else { return false }
        return allPunctuation.contains(last)
    }

    private func endsWithSentencePunctuation(_ source: String) -> Bool {
        guard let last = source.last(where: { !$0.isWhitespace }) else { return false }
        return sentencePunctuation.contains(last)
    }

    private let sentencePunctuation = Set("。！？!?\n")
    private let softPunctuation = Set("，,、；;：:")
    private let allPunctuation = Set("。！？!?\n，,、；;：:…")
    /// A pause after these means the speaker is still thinking, not done.
    private let continuationWords = [
        "以及", "但是", "而且", "因為", "所以", "如果", "然後", "接著", "從", "和", "與", "或", "再",
        "是", "把", "在", "這個", "那個", "就是", "跟", "讓", "給", "被", "對於", "比如", "像是", "還有", "一個",
        "这个", "那个", "让", "对于", "还有", "一个",
    ]
}
