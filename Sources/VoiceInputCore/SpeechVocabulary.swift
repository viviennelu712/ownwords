import Foundation

/// A small, conservative vocabulary layer for AI tool names that speech
/// recognition often gets wrong.
/// The prompt helps Whisper choose the right spelling; post-processing catches
/// common variants when acoustic recognition still misses.
public struct SpeechVocabulary: Sendable {
    public init() {}

    public func correct(_ transcript: String) -> String {
        var result = transcript

        result = replacing(
            pattern: #"(?i)(?<![A-Za-z0-9])(?:norbo|nobo(?:ok)?|no\s*book|note\s*book|notebook)\s*[- ]?\s*l\s*m(?![A-Za-z0-9])"#,
            in: result,
            with: "NotebookLM"
        )
        result = replacing(
            pattern: #"(?i)(?<![A-Za-z0-9])chat\s+g\s*p\s*t(?![A-Za-z0-9])"#,
            in: result,
            with: "ChatGPT"
        )
        result = replacing(
            pattern: #"(?i)(?<![A-Za-z0-9])g\s+p\s+t(?![A-Za-z0-9])"#,
            in: result,
            with: "GPT"
        )

        result = correctClaudeWhenContextIsClear(result)
        return result
    }

    private func correctClaudeWhenContextIsClear(_ source: String) -> String {
        // Chinese characters next to Latin letters do not create a `\b`
        // boundary in ICU regex, so use explicit ASCII guards instead.
        let toolPattern = #"(?i)(?<![A-Za-z0-9])(?:GPT|ChatGPT|NotebookLM|Codex|Notion|Canva)(?![A-Za-z0-9])"#
        guard contains(pattern: toolPattern, in: source) else { return source }

        // Do not globally replace "Cloud": it can genuinely mean cloud storage
        // or cloud services. Only correct it when grammar treats it as another
        // tool in a comparison or selection.
        return replacing(
            pattern: #"(?i)(又用|改用|換成|不要用|使用|跟|和|或|以及|用)\s*Cloud(?![A-Za-z0-9])"#,
            in: source,
            with: "$1Claude"
        )
    }

    private func contains(pattern: String, in source: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.firstMatch(in: source, range: range) != nil
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
