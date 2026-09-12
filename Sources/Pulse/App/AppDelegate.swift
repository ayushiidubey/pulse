import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let preferences = Preferences()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(monitor: monitor, preferences: preferences)
        monitor.start()

        // `open build/Pulse.app --args --show-panel` opens the panel on launch, for development.
        if CommandLine.arguments.contains("--show-panel") {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                statusBar?.showPanel()
            }
        }
    }
}
