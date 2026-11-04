import AppKit
import VoiceInputCore

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let recorder = AudioRecorder()
    private let hotKey = GlobalHotKey()
    private let pushToTalk = FnPushToTalkMonitor()
    private let inserter = TextInserter()
    private let transcriber = TranscriptionService()
    private let cleaner = TranscriptCleaner()
    private let indicator = RecordingIndicator()
    private let personalFiles = PersonalFiles()
    private let recent = RecentTranscripts()
    private let proofreader = ProofreaderService()
    private let proofreadEnabledKey = "proofreadEnabled"
    private var proofreadEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: proofreadEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: proofreadEnabledKey) }
    }

    private var statusItem: NSStatusItem!
    private var instructionWindow: NSWindow?
    private weak var windowStatusLabel: NSTextField?
    private var pendingRelease = false
    private var pendingCancel = false
    /// Fn was tapped (not held): keep listening until the next tap.
    private var handsFree = false
    private var fnPressedAt: Date?
    private var ignoreNextFnRelease = false
    /// Holding Fn shorter than this counts as a tap.
    private let tapThreshold: TimeInterval = 0.35
    private var monitorRetryTimer: Timer?
    private var maximumRecordingTimer: Timer?
    private var state: State = .idle {
        didSet {
            updateMenuBar()
            updateInstructionWindow()
            pushToTalk.isRecording = stateIsRecording
            if !stateIsRecording { handsFree = false }
            updateIndicator()
        }
    }

    private enum State {
        case idle
        case needsAccessibility
        case needsInputMonitoring
        case preparing
        case recording
        case transcribing
        case copied
        case failed(String)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.autosaveName = "LocalVoiceInput.StatusItem"
        hotKey.register { [weak self] in self?.toggleRecording() }
        requestRequiredPermissions()
        configurePushToTalk()
        monitorRetryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.configurePushToTalk() }
        }
        proofreader.onStatusChange = { [weak self] _ in self?.updateMenuBar() }
        if proofreadEnabled { proofreader.start() }
        updateMenuBar()
        showInstructionWindow()
    }

    func applicationWillTerminate(_ notification: Notification) {
        proofreader.stop()
    }

    private func configurePushToTalk() {
        guard !pushToTalk.isRunning else { return }
        guard AXIsProcessTrusted() else {
            if case .idle = state { state = .needsAccessibility }
            return
        }
        guard CGPreflightListenEventAccess() else {
            if case .idle = state { state = .needsInputMonitoring }
            return
        }

        let started = pushToTalk.start(.init(
            onPress: { [weak self] in self?.fnPressed() },
            onRelease: { [weak self] in self?.fnReleased() },
            onOtherKeyWhileFnDown: { [weak self] in self?.fnUsedAsModifier() },
            onEscape: { [weak self] in self?.cancelRecording() }
        ))
        if started {
            switch state {
            case .needsAccessibility, .needsInputMonitoring:
                state = .idle
            default:
                break
            }
        }
    }

    private func requestRequiredPermissions() {
        let hasAccessibility = inserter.requestAccessibilityIfNeeded()
        guard hasAccessibility else {
            state = .needsAccessibility
            return
        }

        if !CGPreflightListenEventAccess() {
            state = .needsInputMonitoring
            _ = CGRequestListenEventAccess()
        }
    }

    private func showInstructionWindow() {
        if let instructionWindow {
            instructionWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "原話 OwnWords"
        window.isReleasedWhenClosed = false
        window.center()

        let title = NSTextField(labelWithString: "原話已啟動")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.alignment = .center

        let instructions = NSTextField(wrappingLabelWithString: "1. 點一下你想輸入文字的位置\n2. 按住\(TriggerKey.current.displayName)說話，放開就貼上\n   或：按一下開始，講完再按一下\n3. 按 Esc 可以取消這一段")
        instructions.font = .systemFont(ofSize: 15)
        instructions.alignment = .left

        let status = NSTextField(labelWithString: stateDescription)
        status.font = .systemFont(ofSize: 13, weight: .medium)
        status.textColor = .secondaryLabelColor
        status.alignment = .center
        windowStatusLabel = status

        let closeButton = NSButton(title: "知道了，隱藏這個視窗", target: self, action: #selector(hideInstructionWindow))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, instructions, status, closeButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(stack)
        window.contentView = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -30),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            instructions.widthAnchor.constraint(equalToConstant: 360),
        ])

        instructionWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateInstructionWindow() {
        windowStatusLabel?.stringValue = stateDescription
    }

    @objc private func hideInstructionWindow() {
        instructionWindow?.orderOut(nil)
    }

    private func toggleRecording() {
        switch state {
        case .idle, .needsAccessibility, .needsInputMonitoring, .copied, .failed:
            beginRecording()
        case .preparing, .recording:
            finishRecording()
        case .transcribing:
            NSSound.beep()
        }
    }

    // MARK: Fn: hold to talk, or tap to start and tap again to finish

    private func fnPressed() {
        if handsFree, stateIsRecording {
            // Second tap ends a hands-free recording.
            handsFree = false
            ignoreNextFnRelease = true
            finishRecording()
            return
        }
        fnPressedAt = Date()
        beginRecording()
    }

    private func fnReleased() {
        if ignoreNextFnRelease {
            ignoreNextFnRelease = false
            return
        }
        guard let pressedAt = fnPressedAt else { return }
        fnPressedAt = nil
        guard stateIsRecording else { return }
        if Date().timeIntervalSince(pressedAt) < tapThreshold {
            handsFree = true
            updateIndicator()
        } else {
            finishRecording()
        }
    }

    /// Fn + another key is a keyboard shortcut, not dictation.
    private func fnUsedAsModifier() {
        guard fnPressedAt != nil, !handsFree else { return }
        fnPressedAt = nil
        cancelRecording()
    }

    private func cancelRecording() {
        guard stateIsRecording else { return }
        handsFree = false
        maximumRecordingTimer?.invalidate()
        maximumRecordingTimer = nil
        if case .preparing = state {
            pendingCancel = true
            return
        }
        recorder.discardCurrentFile()
        state = .idle
    }

    private func beginRecording() {
        switch state {
        case .idle, .needsAccessibility, .needsInputMonitoring, .copied, .failed:
            break
        default:
            return
        }

        pendingRelease = false
        pendingCancel = false
        maximumRecordingTimer?.invalidate()
        maximumRecordingTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishRecording() }
        }
        state = .preparing
        Task {
            do {
                try await recorder.start()
                if pendingCancel {
                    pendingCancel = false
                    recorder.discardCurrentFile()
                    state = .idle
                } else if pendingRelease {
                    stopAndTranscribe()
                } else {
                    state = .recording
                }
            } catch {
                maximumRecordingTimer?.invalidate()
                maximumRecordingTimer = nil
                state = .failed(error.localizedDescription)
                showError(error.localizedDescription)
            }
        }
    }

    private func finishRecording() {
        maximumRecordingTimer?.invalidate()
        maximumRecordingTimer = nil
        if case .preparing = state {
            pendingRelease = true
            return
        }
        guard case .recording = state else { return }
        stopAndTranscribe()
    }

    private func stopAndTranscribe() {
        maximumRecordingTimer?.invalidate()
        maximumRecordingTimer = nil
        guard let file = recorder.stop() else {
            state = .idle
            return
        }

        state = .transcribing
        Task {
            defer { try? FileManager.default.removeItem(at: file) }
            do {
                let rawText = try await transcriber.transcribe(file: file)
                let vocabulary = personalFiles.loadVocabulary()
                let cleaned = cleaner.clean(rawText, userVocabulary: vocabulary)
                guard !cleaned.isEmpty else {
                    state = .failed("沒有辨識到語音。")
                    return
                }
                var text = cleaned
                if proofreadEnabled, proofreader.status == .ready {
                    indicator.show(.working("校對中…"))
                    if let proofread = await proofreader.proofread(cleaned) {
                        text = cleaner.clean(proofread, userVocabulary: vocabulary)
                    }
                }
                recent.add(text)
                personalFiles.archive(text, beforeProofreading: text == cleaned ? nil : cleaned)
                let pasted = inserter.insert(text)
                state = pasted ? .idle : .copied
            } catch {
                state = .failed(error.localizedDescription)
                showError(error.localizedDescription)
            }
        }
    }

    private func updateMenuBar() {
        guard let button = statusItem?.button else { return }
        button.image = nil
        button.imagePosition = .noImage
        button.contentTintColor = nil
        switch state {
        case .idle:
            button.title = "原話"
            button.toolTip = "原話：按住\(TriggerKey.current.shortName)說話，或按一下開始、再按一下結束"
        case .needsAccessibility:
            button.title = "需要權限"
            button.contentTintColor = .systemOrange
            button.toolTip = "請開啟輔助使用權限"
        case .needsInputMonitoring:
            button.title = "需要權限"
            button.contentTintColor = .systemOrange
            button.toolTip = "請開啟輸入監控權限"
        case .preparing:
            button.title = "準備…"
            button.toolTip = "正在開啟麥克風"
        case .recording:
            button.title = "錄音"
            button.contentTintColor = .systemRed
            button.toolTip = "錄音中：放開或再按一下\(TriggerKey.current.shortName)結束；Esc 取消"
        case .transcribing:
            button.title = "辨識…"
            button.toolTip = "辨識中；首次使用會下載本機模型"
        case .copied:
            button.title = "已複製"
            button.toolTip = "辨識完成；請按 Command+V 貼上"
        case .failed:
            button.title = "原話!"
            button.contentTintColor = .systemOrange
            button.toolTip = "發生錯誤；可再按快捷鍵重試"
        }

        let menu = NSMenu()
        let stateItem = NSMenuItem(title: stateDescription, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())

        let toggleTitle = stateIsRecording ? "停止並轉成文字" : "開始錄音"
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(menuToggle), keyEquivalent: "")
        toggle.target = self
        toggle.isEnabled = !stateIsTranscribing
        menu.addItem(toggle)

        menu.addItem(recentMenuItem())
        menu.addItem(triggerMenuItem())
        menu.addItem(.separator())

        let archive = NSMenuItem(title: "原話留底（每天存一份到電腦）", action: #selector(toggleArchive), keyEquivalent: "")
        archive.target = self
        archive.state = personalFiles.archiveEnabled ? .on : .off
        menu.addItem(archive)

        let openArchive = NSMenuItem(title: "打開原話留底資料夾", action: #selector(openArchiveFolder), keyEquivalent: "")
        openArchive.target = self
        menu.addItem(openArchive)

        let proofreadItem = NSMenuItem(title: proofreadMenuTitle, action: #selector(toggleProofread), keyEquivalent: "")
        proofreadItem.target = self
        proofreadItem.state = proofreadEnabled ? .on : .off
        menu.addItem(proofreadItem)

        let vocabulary = NSMenuItem(title: "編輯我的詞庫…", action: #selector(openVocabulary), keyEquivalent: "")
        vocabulary.target = self
        menu.addItem(vocabulary)
        menu.addItem(.separator())

        let permission = NSMenuItem(title: "檢查鍵盤與貼上權限", action: #selector(checkPermission), keyEquivalent: "")
        permission.target = self
        menu.addItem(permission)

        let showWindow = NSMenuItem(title: "顯示使用說明", action: #selector(menuShowWindow), keyEquivalent: "")
        showWindow.target = self
        menu.addItem(showWindow)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "結束", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    private func recentMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "最近說過的話", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let items = recent.items
        if items.isEmpty {
            let empty = NSMenuItem(title: "還沒有紀錄", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        } else {
            let hint = NSMenuItem(title: "點一下就重新貼上（也會留在剪貼簿）", action: nil, keyEquivalent: "")
            hint.isEnabled = false
            submenu.addItem(hint)
            for (index, text) in items.enumerated() {
                let preview = text.replacingOccurrences(of: "\n", with: " ")
                let title = preview.count > 34 ? String(preview.prefix(34)) + "…" : preview
                let entry = NSMenuItem(title: title, action: #selector(pasteRecent(_:)), keyEquivalent: "")
                entry.target = self
                entry.tag = index
                entry.toolTip = text
                submenu.addItem(entry)
            }
            submenu.addItem(.separator())
            let clear = NSMenuItem(title: "清除紀錄", action: #selector(clearRecent), keyEquivalent: "")
            clear.target = self
            submenu.addItem(clear)
        }
        item.submenu = submenu
        return item
    }

    private func triggerMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "說話鍵：\(TriggerKey.current.displayName)", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for key in TriggerKey.allCases {
            let option = NSMenuItem(title: key.displayName, action: #selector(chooseTrigger(_:)), keyEquivalent: "")
            option.target = self
            option.representedObject = key.rawValue
            option.state = key == .current ? .on : .off
            submenu.addItem(option)
        }
        item.submenu = submenu
        return item
    }

    @objc private func chooseTrigger(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let key = TriggerKey(rawValue: raw) else { return }
        TriggerKey.current = key
        pushToTalk.stop()
        configurePushToTalk()
        updateMenuBar()
        updateInstructionWindow()
    }

    private func updateIndicator() {
        switch state {
        case .preparing, .recording:
            indicator.show(
                .listening(handsFree ? "在聽・再按\(TriggerKey.current.shortName)結束" : "在聽"),
                level: { [weak self] in self?.recorder.level() ?? 0 }
            )
        case .transcribing:
            indicator.show(.working("轉文字中…"))
        case .copied:
            indicator.show(.message("已複製，按 ⌘V 貼上"))
        case .failed(let message):
            indicator.show(.message(message == "沒有辨識到語音。" ? "沒聽到聲音" : "出了點問題"))
        case .idle, .needsAccessibility, .needsInputMonitoring:
            indicator.hide()
        }
    }

    private var stateDescription: String {
        switch state {
        case .idle: return "就緒｜按住\(TriggerKey.current.shortName)說話；或按一下開始、再按一下結束"
        case .needsAccessibility: return "尚未啟用輔助使用權限｜點上方「語音」檢查"
        case .needsInputMonitoring: return "尚未啟用輸入監控｜請到系統設定勾選「語音輸入」"
        case .preparing: return "正在準備麥克風…"
        case .recording: return "正在錄音…"
        case .transcribing: return "正在本機辨識…"
        case .copied: return "已辨識並複製；請按 Command+V 貼上"
        case .failed(let message): return "錯誤：\(message)"
        }
    }

    private var stateIsRecording: Bool {
        switch state {
        case .preparing, .recording: return true
        default: return false
        }
    }

    private var stateIsTranscribing: Bool {
        if case .transcribing = state { return true }
        return false
    }

    @objc private func menuToggle() { toggleRecording() }
    @objc private func menuShowWindow() { showInstructionWindow() }
    @objc private func checkPermission() {
        requestRequiredPermissions()
        configurePushToTalk()
        showInstructionWindow()
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    @objc private func toggleArchive() {
        personalFiles.archiveEnabled.toggle()
        updateMenuBar()
    }
    private var proofreadMenuTitle: String {
        guard proofreadEnabled else { return "本機 AI 校對（改錯字、英文、改口、問號）" }
        switch proofreader.status {
        case .ready: return "本機 AI 校對：開著"
        case .starting: return "本機 AI 校對：準備中…"
        case .unavailable(let reason): return "本機 AI 校對：\(reason)"
        case .off: return "本機 AI 校對：關"
        }
    }

    @objc private func toggleProofread() {
        proofreadEnabled.toggle()
        if proofreadEnabled { proofreader.start() } else { proofreader.stop() }
        updateMenuBar()
    }

    @objc private func openArchiveFolder() { personalFiles.openArchiveFolder() }
    @objc private func openVocabulary() { personalFiles.openVocabulary() }
    @objc private func clearRecent() {
        recent.clear()
        updateMenuBar()
    }
    @objc private func pasteRecent(_ sender: NSMenuItem) {
        let items = recent.items
        guard items.indices.contains(sender.tag) else { return }
        let text = items[sender.tag]
        // Let the menu close and focus return to the previous app first.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.inserter.insert(text, restoreClipboard: false)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "語音輸入發生問題"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
