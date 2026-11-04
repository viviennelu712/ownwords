import AppKit
import ApplicationServices

/// A small pill that floats next to the text cursor (or at the bottom of the
/// screen when the app does not report a cursor position), so you can tell
/// whether it is listening without looking at the menu bar.
@MainActor
final class RecordingIndicator {
    enum Mode {
        case listening(String)
        case working(String)
        case message(String)
    }

    private let panel: NSPanel
    private let dot = NSView()
    private let label = NSTextField(labelWithString: "")
    private let bars: [NSView] = (0..<5).map { _ in NSView() }
    private let barStack: NSStackView
    private var levelTimer: Timer?
    private var hideWorkItem: DispatchWorkItem?

    private let height: CGFloat = 34

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 17
        background.layer?.masksToBounds = true

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = NSColor.systemRed.cgColor

        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .labelColor

        for bar in bars {
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 1.5
            bar.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.75).cgColor
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.widthAnchor.constraint(equalToConstant: 3).isActive = true
            bar.heightAnchor.constraint(equalToConstant: 4).isActive = true
        }
        barStack = NSStackView(views: bars)
        barStack.orientation = .horizontal
        barStack.alignment = .centerY
        barStack.spacing = 2

        let row = NSStackView(views: [dot, label, barStack])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.translatesAutoresizingMaskIntoConstraints = false
        dot.translatesAutoresizingMaskIntoConstraints = false

        background.addSubview(row)
        panel.contentView = background
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            barStack.heightAnchor.constraint(equalToConstant: 18),
            row.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 13),
            row.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -13),
            row.centerYAnchor.constraint(equalTo: background.centerYAnchor),
        ])
    }

    func show(_ mode: Mode, level: (() -> Float)? = nil) {
        hideWorkItem?.cancel()
        levelTimer?.invalidate()
        levelTimer = nil

        switch mode {
        case .listening(let text):
            label.stringValue = text
            dot.layer?.backgroundColor = NSColor.systemRed.cgColor
            barStack.isHidden = false
            if let level {
                levelTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.render(level: level()) }
                }
            }
        case .working(let text):
            label.stringValue = text
            dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            barStack.isHidden = true
        case .message(let text):
            label.stringValue = text
            dot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            barStack.isHidden = true
            scheduleHide(after: 1.8)
        }

        resizeAndPlace()
        panel.orderFrontRegardless()
    }

    func hide() {
        hideWorkItem?.cancel()
        levelTimer?.invalidate()
        levelTimer = nil
        panel.orderOut(nil)
    }

    private func scheduleHide(after seconds: TimeInterval) {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.hide() }
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func render(level: Float) {
        // Centre bars react most, like a small equaliser.
        let weights: [CGFloat] = [0.55, 0.8, 1, 0.8, 0.55]
        for (bar, weight) in zip(bars, weights) {
            let target = 4 + CGFloat(level) * 14 * weight
            bar.constraints.first { $0.firstAttribute == .height }?.constant = target
        }
    }

    private func resizeAndPlace() {
        panel.contentView?.layoutSubtreeIfNeeded()
        let width = max(96, (panel.contentView?.fittingSize.width ?? 120))
        let origin = anchorPoint(width: width)
        panel.setFrame(NSRect(x: origin.x, y: origin.y, width: width, height: height), display: true)
    }

    private func anchorPoint(width: CGFloat) -> NSPoint {
        if let caret = caretRectInCocoaCoordinates(),
           let screen = NSScreen.screens.first(where: { $0.frame.contains(caret.origin) }) {
            var x = caret.minX
            var y = caret.minY - height - 8
            if y < screen.visibleFrame.minY { y = caret.maxY + 8 }
            x = min(max(x, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
            return NSPoint(x: x, y: y)
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        return NSPoint(x: frame.midX - width / 2, y: frame.minY + 60)
    }

    /// Asks the focused app where its text cursor is. Many apps answer;
    /// browsers and some editors do not, which is fine — we fall back.
    private func caretRectInCocoaCoordinates() -> NSRect? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else { return nil }
        let element = focused as! AXUIElement

        var selection: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selection) == .success,
              let selection
        else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selection,
            &boundsValue
        ) == .success,
            let boundsValue, CFGetTypeID(boundsValue) == AXValueGetTypeID()
        else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect),
              rect.origin != .zero, rect.height > 0, rect.height < 200
        else { return nil }

        // Accessibility uses a top-left origin on the primary screen.
        guard let primary = NSScreen.screens.first else { return nil }
        return NSRect(x: rect.minX, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
