import Foundation

/// "Recognize, don't rewrite": decides whether the local AI's proofread may
/// replace the original transcript. Proofreading fixes a few characters;
/// anything that changes much more than that is treated as rewriting and
/// thrown away, so the speaker gets their own words back.
public struct ProofreadGuard: Sendable {
    /// Minimum share of characters that must stay the same.
    public let minimumSimilarity: Double
    /// Looser limit when the speaker explicitly corrected themselves
    /// ("不對", "我是說"), because the replaced part is dropped.
    public let minimumSimilarityWithSelfCorrection: Double

    public init(minimumSimilarity: Double = 0.88, minimumSimilarityWithSelfCorrection: Double = 0.78) {
        self.minimumSimilarity = minimumSimilarity
        self.minimumSimilarityWithSelfCorrection = minimumSimilarityWithSelfCorrection
    }

    public func accepts(original: String, proofread: String) -> Bool {
        let output = proofread.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else { return false }
        guard Double(output.count) <= Double(original.count) * 1.15 + 4 else { return false }

        let selfCorrected = ["不對", "不是，", "我是說", "應該是", "講錯"].contains { original.contains($0) }
        let limit = selfCorrected ? minimumSimilarityWithSelfCorrection : minimumSimilarity
        return similarity(normalized(original), normalized(output)) >= limit
    }

    private func normalized(_ text: String) -> [Character] {
        let ignored = Set(" \n\t，。！？、,.!?：:；;「」⋯…")
        return text.filter { !ignored.contains($0) }.map { $0 }
    }

    /// 2·matches / total, matches counted by longest common subsequence —
    /// the same idea as Python's difflib ratio, close enough for a guard.
    private func similarity(_ a: [Character], _ b: [Character]) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = [Int](repeating: 0, count: b.count + 1)
        var current = previous
        for i in 1...a.count {
            for j in 1...b.count {
                current[j] = a[i - 1] == b[j - 1]
                    ? previous[j - 1] + 1
                    : max(previous[j], current[j - 1])
            }
            swap(&previous, &current)
        }
        return 2 * Double(previous[b.count]) / Double(a.count + b.count)
    }
}
