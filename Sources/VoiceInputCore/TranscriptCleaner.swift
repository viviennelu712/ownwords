import Foundation

public struct TranscriptCleaner: Sendable {
    private let vocabulary = SpeechVocabulary()
    private let contextualCorrector = TranscriptContextualCorrector()
    private let hallucinations = HallucinationFilter()
    private let restarts = RestartRemover()

    public init() {}

    public func clean(
        _ transcript: String,
        userVocabulary: UserVocabulary = UserVocabulary(rules: [])
    ) -> String {
        var result = transcript
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        result = replacing(
            // Only hesitation sounds. Words like 那個、就是說 are part of how
            // the speaker talks and are kept.
            pattern: #"^(?:(?:嗯+|呃+|額+)[，,、。\s]*)+"#,
            in: result,
            with: ""
        )
        result = replacing(
            pattern: #"([，。！？；])(?:嗯+|呃+|額+)[，,、\s]*"#,
            in: result,
            with: "$1"
        )
        // A hesitation sound at the very end: 「藍色色票排好了嗯。」
        result = replacing(pattern: #"(?<=[\p{Han}A-Za-z0-9])(?:嗯+|呃+)([。！？]?)\s*$"#, in: result, with: "$1")
        result = replacing(pattern: #"[ \t]+([，。！？；：、])"#, in: result, with: "$1")
        result = replacing(pattern: #"([，。！？；：、])[ \t]+"#, in: result, with: "$1")
        result = replacing(pattern: #"[ \t]{2,}"#, in: result, with: " ")
        result = replacing(pattern: #"\n{3,}"#, in: result, with: "\n\n")
        result = replacing(pattern: #"([\p{Han}])\s*,\s*"#, in: result, with: "$1，")
        result = replacing(pattern: #"\s*,\s*(?=[\p{Han}])"#, in: result, with: "，")
        result = replacing(pattern: #"([\p{Han}])\s*\."#, in: result, with: "$1。")
        result = replacing(pattern: #"\s*\.(?=[\p{Han}])"#, in: result, with: "。")
        result = replacing(pattern: #"([\p{Han}])\s*\?"#, in: result, with: "$1？")
        result = replacing(pattern: #"\s*\?(?=[\p{Han}])"#, in: result, with: "？")
        result = replacing(pattern: #"([\p{Han}])\s*!"#, in: result, with: "$1！")
        result = replacing(pattern: #"\s*!(?=[\p{Han}])"#, in: result, with: "！")
        result = replacing(pattern: #"[（(]\s*字幕君\s*[）)]"#, in: result, with: "")
        result = replacing(pattern: #"字幕由[^。！？\n]{0,30}(?:提供|製作|整理)"#, in: result, with: "")
        // "。..。" left behind while searching for a word.
        result = replacing(pattern: #"(?:[。，]\s*)?\.{2,}(?:\s*[。，])?"#, in: result, with: "⋯")
        result = collapseDuplicateHalves(result)
        result = toTraditionalChinese(result)
        result = vocabulary.correct(result)
        result = contextualCorrector.correct(result)
        result = restarts.clean(result)
        result = fullWidthEndingsAfterEnglish(result)
        result = addQuestionMarks(result)
        result = userVocabulary.correct(result)
        result = hallucinations.clean(result)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// In Chinese text, "deadline?" becomes "deadline？" like the rest.
    private func fullWidthEndingsAfterEnglish(_ source: String) -> String {
        guard source.range(of: #"\p{Han}"#, options: .regularExpression) != nil else { return source }
        var result = replacing(pattern: #"([A-Za-z0-9])\s*\?(?=$|\n|\s*\p{Han})"#, in: source, with: "$1？")
        result = replacing(pattern: #"([A-Za-z0-9])\s*!(?=$|\n|\s*\p{Han})"#, in: result, with: "$1！")
        return result
    }

    /// A sentence that ends in a question particle gets a question mark.
    /// 呢 only counts when the sentence also has a question word, because
    /// 「還在跑呢」 is a statement.
    private func addQuestionMarks(_ source: String) -> String {
        var result = replacing(
            pattern: #"(嗎|么|對不對|對吧|是不是|好不好|行不行|可不可以|要不要|有沒有|能不能|會不會|對嗎)(?:[。.]|(?=$|\n))"#,
            in: source,
            with: "$1？"
        )
        result = replacing(
            pattern: #"([^。！？\n]*(?:什麼|怎麼|哪|誰|為什麼|如何|多少|幾個)[^。！？\n]*呢)(?:[。.]|(?=$|\n))"#,
            in: result,
            with: "$1？"
        )
        return result.replacingOccurrences(of: "？？", with: "？")
    }

    private func replacing(pattern: String, in source: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return source
        }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.stringByReplacingMatches(
            in: source,
            range: range,
            withTemplate: replacement
        )
    }

    private func collapseDuplicateHalves(_ source: String) -> String {
        let characters = Array(source)
        guard characters.count >= 12, characters.count.isMultiple(of: 2) else { return source }
        let midpoint = characters.count / 2
        let first = String(characters[..<midpoint])
        let second = String(characters[midpoint...])
        let normalizedFirst = first.filter { !$0.isWhitespace }
        let normalizedSecond = second.filter { !$0.isWhitespace }
        return normalizedFirst == normalizedSecond ? first : source
    }

    private func toTraditionalChinese(_ source: String) -> String {
        let mutable = NSMutableString(string: source)
        CFStringTransform(mutable, nil, "Hans-Hant" as CFString, false)
        return toTaiwanVariants(mutable as String)
    }

    /// The system converter leaves 里 where Taiwan writes 裡 ("電腦里" →
    /// "電腦裡"), plus a few other mainland word forms.
    private func toTaiwanVariants(_ source: String) -> String {
        var result = source.replacingOccurrences(of: "裏", with: "裡")
        // Taiwan writes 裡 for "inside"; 里 only survives in distances and
        // neighbourhoods (公里、英里、千里、鄰里、故里、里長、里程…).
        result = replacing(
            pattern: #"(?<![公英海千萬鄰鄉故百華])里(?![長民程拉約])"#,
            in: result,
            with: "裡"
        )
        // Other words the system converter leaves in the mainland form.
        let words = [
            "錄制": "錄製", "重復": "重複", "准則": "準則", "標准": "標準",
            "准備": "準備", "准確": "準確", "水准": "水準", "精准": "精準",
        ]
        for (from, to) in words {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result
    }
}
