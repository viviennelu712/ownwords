import Foundation

/// Whisper learned from video subtitles, so when the speaker stops it tends
/// to "finish the video" with a sign-off nobody said. Only phrases at the very
/// end of a piece of text are removed; the same words mid-sentence stay.
public struct HallucinationFilter: Sendable {
    public init() {}

    private static let trailingPattern =
        #"(?:[，,。！!？?、\s]*(?:"# +
        #"謝謝大家|谢谢大家|感謝觀看|感谢观看|謝謝觀看|谢谢观看|謝謝收看|谢谢收看|感謝收看|感谢收看|"# +
        #"感謝您的觀看|感谢您的观看|謝謝您的觀看|谢谢您的观看|"# +
        #"請不吝點[贊讚][^。！？\n]*|请不吝点赞[^。！？\n]*|"# +
        #"[^。！？\n]{0,12}(?:點[贊讚]|点赞)[^。！？\n]{0,12}(?:訂閱|订阅)[^。！？\n]*|"# +
        #"(?:字幕|中文字幕)(?:由|提供|製作|制作)[^。！？\n]*|"# +
        #"明鏡與點點欄目|明镜与点点栏目"# +
        #")[。！!？?\s]*)+$"#

    public func clean(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: Self.trailingPattern) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let stripped = expression.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        guard stripped != text else { return text }
        // Keep a sentence end on whatever is left.
        var result = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = result.last, "，,、".contains(last) {
            result.removeLast()
        }
        if let last = result.last, !"。！？!?…⋯".contains(last) {
            result += "。"
        }
        return result
    }
}
