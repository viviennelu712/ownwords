import ApplicationServices
import Foundation

/// The key you hold (or tap) to dictate. Fn is the classic choice, but on
/// Macs where 🌐 switches input sources the two fight, so a right-hand
/// modifier that nothing else uses on its own is the default.
enum TriggerKey: String, CaseIterable {
    case rightOption
    case rightCommand
    case fn

    static let defaultsKey = "triggerKey"

    static var current: TriggerKey {
        get { TriggerKey(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .rightOption }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }

    var displayName: String {
        switch self {
        case .rightOption: return "右邊 ⌥ Option"
        case .rightCommand: return "右邊 ⌘ Command"
        case .fn: return "Fn（🌐）"
        }
    }

    /// Short name for hints, e.g. 「按住右 ⌥ 說話」.
    var shortName: String {
        switch self {
        case .rightOption: return "右 ⌥"
        case .rightCommand: return "右 ⌘"
        case .fn: return "Fn"
        }
    }

    var keyCode: Int64 {
        switch self {
        case .rightOption: return 61
        case .rightCommand: return 54
        case .fn: return 63
        }
    }

    /// Device-specific modifier bit, so the left-hand key never triggers it.
    var flagMask: UInt64 {
        switch self {
        case .rightOption: return 0x40       // NX_DEVICERALTKEYMASK
        case .rightCommand: return 0x10      // NX_DEVICERCMDKEYMASK
        case .fn: return CGEventFlags.maskSecondaryFn.rawValue
        }
    }
}

/// Watches the trigger key (see `TriggerKey`) system-wide.
///
/// Besides Fn going down and up, it reports two things the controller needs
/// to tell dictation apart from ordinary keyboard use:
/// - another key pressed while Fn is held (Fn + arrow, Fn + F-key…), which
///   means Fn is being used as a modifier, not to talk;
/// - Escape, which cancels a recording. Escape is swallowed only while
///   `isRecording` is true, so it keeps working normally the rest of the time.
@MainActor
final class FnPushToTalkMonitor {
    struct Handlers {
        var onPress: () -> Void
        var onRelease: () -> Void
        var onOtherKeyWhileFnDown: () -> Void
        var onEscape: () -> Void
    }

    /// Set by the controller; read synchronously inside the event tap, which
    /// runs on the main run loop.
    var isRecording = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isFnDown = false
    private var handlers: Handlers?
    private(set) var isRunning = false

    private static let escapeKeyCode: Int64 = 53
    private var trigger: TriggerKey = .current

    @discardableResult
    func start(_ handlers: Handlers) -> Bool {
        stop()
        self.handlers = handlers
        trigger = .current

        let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<FnPushToTalkMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                return MainActor.assumeIsolated {
                    monitor.handle(type: type, event: event)
                }
            },
            userInfo: userInfo
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        isFnDown = false
        isRunning = false
        handlers = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if type == .keyDown {
            if keyCode == Self.escapeKeyCode, isRecording {
                handlers?.onEscape()
                return nil
            }
            if isFnDown {
                handlers?.onOtherKeyWhileFnDown()
            }
            return Unmanaged.passUnretained(event)
        }

        // flagsChanged. Some Mac keyboards report a different key code when
        // Fn is released, so watch the key's flag on every modifier change.
        let isDown = event.flags.rawValue & trigger.flagMask != 0
        if isDown != isFnDown {
            isFnDown = isDown
            if isDown {
                handlers?.onPress()
            } else {
                handlers?.onRelease()
            }
        }
        // Only Fn is swallowed (so 🌐 does less); right ⌥/⌘ pass through
        // untouched and keep working as normal modifiers.
        return trigger == .fn && keyCode == trigger.keyCode ? nil : Unmanaged.passUnretained(event)
    }
}
