import AppKit
import VoiceInputCore

/// The two files that belong to the person, not the program: their word list
/// and (only if they turn it on) a daily archive of everything they said.
@MainActor
final class PersonalFiles {
    private let defaults = UserDefaults.standard
    private let archiveEnabledKey = "archiveEnabled"
    private let archiveFolderKey = "archiveFolder"

    private var supportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OwnWords", isDirectory: true)
    }

    var vocabularyFile: URL { supportFolder.appendingPathComponent("我的詞庫.txt") }

    // MARK: Word list

    func loadVocabulary() -> UserVocabulary {
        ensureVocabularyFile()
        let contents = (try? String(contentsOf: vocabularyFile, encoding: .utf8)) ?? ""
        return UserVocabulary(fileContents: contents)
    }

    func openVocabulary() {
        ensureVocabularyFile()
        NSWorkspace.shared.open(vocabularyFile)
    }

    private func ensureVocabularyFile() {
        guard !FileManager.default.fileExists(atPath: vocabularyFile.path) else { return }
        try? FileManager.default.createDirectory(at: supportFolder, withIntermediateDirectories: true)
        let template = """
        # 我的詞庫
        # 每一行寫「聽錯的 → 正確的」，存檔後下一句就生效。
        # 英文不分大小寫；開頭是 # 的行不會被讀。
        #
        # 例如：
        # Cloud Code → Claude Code

        """
        try? template.write(to: vocabularyFile, atomically: true, encoding: .utf8)
    }

    // MARK: Archive of original words

    var archiveEnabled: Bool {
        get { defaults.bool(forKey: archiveEnabledKey) }
        set { defaults.set(newValue, forKey: archiveEnabledKey) }
    }

    var archiveFolder: URL {
        if let custom = defaults.string(forKey: archiveFolderKey), !custom.isEmpty {
            return URL(fileURLWithPath: (custom as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("原話留底", isDirectory: true)
    }

    /// Appends one entry to today's file, e.g. `原話留底/2026-10-12.md`.
    func archive(_ text: String, beforeProofreading: String? = nil, at date: Date = Date()) {
        guard archiveEnabled else { return }
        let folder = archiveFolder
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let time = DateFormatter()
        time.locale = Locale(identifier: "en_US_POSIX")
        time.dateFormat = "HH:mm:ss"

        let file = folder.appendingPathComponent("\(day.string(from: date)).md")
        let isNew = !FileManager.default.fileExists(atPath: file.path)
        let header = isNew ? "# \(day.string(from: date)) 原話\n" : ""
        var entry = header + "\n## \(time.string(from: date))\n\n\(text)\n"
        if let beforeProofreading {
            // Kept so a later review can check the AI only fixed, never rewrote.
            entry += "\n> 校對前：\(beforeProofreading)\n"
        }

        if isNew {
            try? entry.write(to: file, atomically: true, encoding: .utf8)
        } else if let handle = try? FileHandle(forWritingTo: file) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(entry.utf8))
        }
    }

    func openArchiveFolder() {
        try? FileManager.default.createDirectory(at: archiveFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(archiveFolder)
    }
}
