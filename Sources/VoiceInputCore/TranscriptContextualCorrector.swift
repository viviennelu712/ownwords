import Foundation

/// Repairs high-confidence speech artifacts without paraphrasing the user's
/// meaning. This deliberately stays more conservative than an LLM rewrite.
public struct TranscriptContextualCorrector: Sendable {
    public init() {}

    public func correct(_ transcript: String) -> String {
        var result = transcript

        // A pause can split a repeated bridge word into "到。到展示樣本".
        // Keep one copy and remove the false sentence boundary.
        result = replacing(
            pattern: #"(然後|所以|但是|而且|因為|如果|接著|從|到|和|與|或|再)\s*[，。！？,!?]\s*\1"#,
            in: result,
            with: "$1"
        )

        // Whisper occasionally duplicates a discourse marker without adding
        // punctuation between the copies.
        result = replacing(
            pattern: #"(就是|然後|我覺得|那個)\s*[，、,\s]*\1"#,
            in: result,
            with: "$1"
        )

        // A sentence should rarely end immediately after a continuation word.
        // Downgrade that boundary to a comma while keeping the wording intact.
        result = replacing(
            pattern: #"(以及|但是|而且|因為|所以|如果|然後|接著|從|和|與|或|再|是|把|在|這個|那個|就是|跟|讓|給|被|對於|比如|像是|還有|一個|我們|你|我)[。](?=[^。！？\n])"#,
            in: result,
            with: "$1，"
        )

        result = replacing(pattern: #"[，,]{2,}"#, in: result, with: "，")
        return result
    }

    private func replacing(pattern: String, in source: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return source }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.stringByReplacingMatches(
            in: source,
            range: range,
            withTemplate: replacement
        )
    }
}
