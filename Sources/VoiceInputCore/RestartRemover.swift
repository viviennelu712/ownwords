import Foundation

/// When a speaker starts a phrase and then says it again properly —
/// 「不要太亮。不要把它調太亮。」— only the second attempt is kept.
///
/// Deliberately narrow: the first clause must reappear, in order, inside the
/// very next clause (a first draft of it), so ordinary repetition for emphasis
/// or two different sentences are never touched.
public struct RestartRemover: Sendable {
    public init() {}

    private static let clauseEnds = Set("，。！？；,!?;")
    private static let ignored = Set(" \t，。！？；、,!?;：:「」")

    public func clean(_ text: String) -> String {
        let clauses = split(text)
        guard clauses.count >= 2 else { return text }

        var kept: [String] = []
        for (index, clause) in clauses.enumerated() {
            if index + 1 < clauses.count, isFirstDraft(clause, of: clauses[index + 1]) {
                continue
            }
            kept.append(clause)
        }
        return kept.joined()
    }

    /// Splits after each clause-ending mark, keeping the mark with its clause.
    private func split(_ text: String) -> [String] {
        var clauses: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if Self.clauseEnds.contains(character) {
                clauses.append(current)
                current = ""
            }
        }
        if !current.isEmpty { clauses.append(current) }
        return clauses
    }

    private func isFirstDraft(_ first: String, of second: String) -> Bool {
        let a = Array(first.filter { !Self.ignored.contains($0) })
        let b = Array(second.filter { !Self.ignored.contains($0) })
        // Too short to tell a restart from emphasis ("很好。很好很好").
        guard a.count >= 3, b.count > a.count, b.count <= a.count * 3 else { return false }
        // Must start the same way, like a real restart does.
        guard a.first == b.first else { return false }
        var position = b.startIndex
        for character in a {
            guard let found = b[position...].firstIndex(of: character) else { return false }
            position = b.index(after: found)
        }
        return true
    }
}
