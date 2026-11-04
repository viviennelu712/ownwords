import Foundation

/// Personal word list kept in a plain text file, one rule per line:
///
///     錯的寫法 → 對的寫法
///
/// `->` and `=>` also work. Lines starting with `#` are comments. Latin
/// letters match case-insensitively; nothing else about the text changes.
public struct UserVocabulary: Sendable, Equatable {
    public struct Rule: Sendable, Equatable {
        public let heard: String
        public let written: String
    }

    public let rules: [Rule]

    public init(rules: [Rule]) {
        // Longer phrases first, so "Cloud Code → Claude Code" wins over a
        // shorter rule that would match inside it.
        self.rules = rules.sorted { $0.heard.count > $1.heard.count }
    }

    public init(fileContents: String) {
        let separators = ["→", "=>", "->"]
        var parsed: [Rule] = []
        for rawLine in fileContents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            guard let separator = separators.first(where: { line.contains($0) }),
                  let range = line.range(of: separator)
            else { continue }
            let heard = line[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            let written = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            guard !heard.isEmpty, !written.isEmpty, heard != written else { continue }
            parsed.append(Rule(heard: heard, written: written))
        }
        self.init(rules: parsed)
    }

    public func correct(_ transcript: String) -> String {
        guard !rules.isEmpty else { return transcript }
        // One pass over the text, so a replacement is never matched again by
        // a later rule ("Cloud Storage" stays intact even if "Cloud" is a rule).
        let alternatives = rules.map { rule -> String in
            let escaped = NSRegularExpression.escapedPattern(for: rule.heard)
            // Keep English words whole: "Cloud" must not change "Clouds".
            let leading = rule.heard.first?.isASCIILetterOrDigit == true ? "(?<![A-Za-z0-9])" : ""
            let trailing = rule.heard.last?.isASCIILetterOrDigit == true ? "(?![A-Za-z0-9])" : ""
            return "(" + leading + escaped + trailing + ")"
        }
        guard let expression = try? NSRegularExpression(
            pattern: alternatives.joined(separator: "|"),
            options: [.caseInsensitive]
        ) else { return transcript }

        let source = transcript as NSString
        var result = ""
        var cursor = 0
        for match in expression.matches(in: transcript, range: NSRange(location: 0, length: source.length)) {
            guard let index = (1...rules.count).first(where: { match.range(at: $0).location != NSNotFound }) else {
                continue
            }
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            result += rules[index - 1].written
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }
}

private extension Character {
    var isASCIILetterOrDigit: Bool { isASCII && (isLetter || isNumber) }
}
