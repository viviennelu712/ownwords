import Foundation
import VoiceInputCore

/// Talks to the local proofreading model (proofreader/proofread_server.py),
/// which runs as a separate process so the model stays loaded between
/// sentences. Optional: if Python, mlx-lm or the model is missing, or an
/// answer is slow, dictation simply uses the text without proofreading.
@MainActor
final class ProofreaderService {
    enum Status: Equatable {
        case off
        case starting
        case ready
        case unavailable(String)
    }

    private(set) var status: Status = .off {
        didSet { onStatusChange?(status) }
    }
    var onStatusChange: ((Status) -> Void)?

    private let guardrail = ProofreadGuard()
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var nextID = 1
    private var waiting: [Int: CheckedContinuation<String?, Never>] = [:]

    private static let pythonKey = "proofreadPython"
    private static let defaultPython = "~/.local/share/uv/tools/mlx-lm/bin/python"

    func start() {
        guard process == nil else { return }
        let pythonPath = ((UserDefaults.standard.string(forKey: Self.pythonKey) ?? Self.defaultPython)
            as NSString).expandingTildeInPath
        guard FileManager.default.isExecutableFile(atPath: pythonPath) else {
            status = .unavailable("找不到本機 AI（mlx-lm）")
            return
        }
        // A copy in Application Support wins over the one inside the app, so
        // the proofreading rules can be updated without reinstalling (which
        // would make macOS ask for permissions again).
        let override = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OwnWords/proofreader/proofread_server.py")
        let bundled = Bundle.main.url(forResource: "proofread_server", withExtension: "py", subdirectory: "proofreader")
        guard let script = FileManager.default.fileExists(atPath: override.path) ? override : bundled else {
            status = .unavailable("App 裡缺少校對程式")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = [script.path]
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            Task { @MainActor in self?.handleExit() }
        }
        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor in self?.receive(data) }
        }

        do {
            try process.run()
        } catch {
            status = .unavailable("本機 AI 啟動失敗")
            return
        }
        self.process = process
        input = stdinPipe.fileHandleForWriting
        status = .starting
    }

    func stop() {
        process?.terminationHandler = nil
        process?.terminate()
        handleExit()
        status = .off
    }

    /// Returns the proofread text when the model answers in time and the
    /// guard agrees it only fixed recognition errors; otherwise `nil`.
    func proofread(_ text: String) async -> String? {
        guard status == .ready, let input, !text.isEmpty else { return nil }
        let id = nextID
        nextID += 1
        let request = try? JSONSerialization.data(withJSONObject: ["id": id, "text": text])
        guard var line = request else { return nil }
        line.append(0x0A)

        // A few seconds plus a little per character; longer dictation takes longer.
        let timeout = 3.0 + Double(text.count) * 0.03
        let answer: String? = await withCheckedContinuation { continuation in
            waiting[id] = continuation
            input.write(line)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.finish(id, with: nil)
            }
        }
        guard let answer, guardrail.accepts(original: text, proofread: answer) else { return nil }
        return answer
    }

    private func finish(_ id: Int, with text: String?) {
        waiting.removeValue(forKey: id)?.resume(returning: text)
    }

    private func receive(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            if object["ready"] as? Bool == true {
                status = .ready
            } else if let id = object["id"] as? Int {
                finish(id, with: object["text"] as? String)
            }
        }
    }

    private func handleExit() {
        for id in Array(waiting.keys) { finish(id, with: nil) }
        process = nil
        input = nil
        buffer.removeAll()
        if status == .starting || status == .ready {
            status = .unavailable("本機 AI 停止了")
        }
    }
}
