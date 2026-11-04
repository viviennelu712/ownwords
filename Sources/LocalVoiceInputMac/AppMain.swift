import AppKit
import Foundation

@main
enum LocalVoiceInputApp {
    @MainActor
    static func main() {
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier })
        {
            existing.activate(options: [.activateAllWindows])
            return
        }

        let app = NSApplication.shared
        let delegate = AppController()
        app.delegate = delegate
        app.run()
    }
}
