import Foundation

public struct TranscriptMerger: Sendable {
    public init() {}

    public func merge(_ parts: [String]) -> String {
        var merged = ""

        for rawPart in parts {
            let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }

            if merged.isEmpty {
                merged = part
                continue
            }
            if part == merged || merged.hasSuffix(part) {
                continue
            }
            if part.hasPrefix(merged) {
                merged = part
                continue
            }

            var overlapBase = merged
            var mergedCharacters = Array(overlapBase)
            let partCharacters = Array(part)
            var overlap = overlapLength(left: mergedCharacters, right: partCharacters)

            // Each independently decoded chunk can now end in a guaranteed period.
            // Ignore that artificial boundary when the next chunk starts by repeating
            // the tail of the previous chunk.
            if overlap == 0, let last = mergedCharacters.last, boundaryPunctuation.contains(last) {
                overlapBase.removeLast()
                mergedCharacters = Array(overlapBase)
                overlap = overlapLength(left: mergedCharacters, right: partCharacters)
            }

            if overlap > 0 {
                merged = overlapBase
            }
            let separator = needsSeparator(after: merged, before: part) ? " " : ""
            merged += separator + String(partCharacters.dropFirst(overlap))
        }

        return merged
    }

    private func overlapLength(left: [Character], right: [Character]) -> Int {
        let maximumOverlap = min(left.count, right.count, 200)
        guard maximumOverlap > 0 else { return 0 }

        for length in stride(from: maximumOverlap, through: 1, by: -1) {
            if left.suffix(length).elementsEqual(right.prefix(length)) {
                return length
            }
        }
        return 0
    }

    private func needsSeparator(after left: String, before right: String) -> Bool {
        guard let last = left.last, let first = right.first else { return false }
        return last.isASCII && first.isASCII && last.isLetter && first.isLetter
    }

    private let boundaryPunctuation = Set("。！？!?，,；;：:")
}
