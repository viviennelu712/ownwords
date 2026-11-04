import Foundation

/// The last few results, so a sentence that landed in the wrong window (or
/// nowhere) can be pasted again instead of spoken again.
@MainActor
final class RecentTranscripts {
    private let key = "recentTranscripts"
    private let limit = 20

    private(set) var items: [String] {
        get { UserDefaults.standard.stringArray(forKey: key) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    func add(_ text: String) {
        var updated = items.filter { $0 != text }
        updated.insert(text, at: 0)
        items = Array(updated.prefix(limit))
    }

    func clear() {
        items = []
    }
}
