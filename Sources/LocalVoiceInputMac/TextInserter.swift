import AppKit
import ApplicationServices

@MainActor
final class TextInserter {
    func requestAccessibilityIfNeeded() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Pastes `text` at the cursor. By default whatever was on the clipboard
    /// before is put back afterwards, so dictation never costs you a copy.
    @discardableResult
    func insert(_ text: String, restoreClipboard: Bool = true) -> Bool {
        let pasteboard = NSPasteboard.general
        let saved = restoreClipboard ? snapshot(pasteboard) : nil
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard requestAccessibilityIfNeeded() else {
            // Could not paste, so leave the text on the clipboard for ⌘V.
            return false
        }

        guard
            let source = CGEventSource(stateID: .combinedSessionState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)

        if let saved {
            let ourChange = pasteboard.changeCount
            // The target app reads the clipboard asynchronously after ⌘V;
            // give it time before putting the old contents back.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                // If something else was copied meanwhile, leave it alone.
                guard pasteboard.changeCount == ourChange else { return }
                pasteboard.clearContents()
                if !saved.isEmpty {
                    pasteboard.writeObjects(saved)
                }
            }
        }
        return true
    }

    private func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
    }
}
