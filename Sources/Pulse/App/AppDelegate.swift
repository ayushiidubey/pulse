import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = SystemMonitor()
    private let preferences = Preferences()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(monitor: monitor, preferences: preferences)
        monitor.start()

        // Development flags: `open build/Pulse.app --args --show-panel --speed-test`.
        // Both wait briefly so the status item is laid out and the first network path has arrived.
        let arguments = CommandLine.arguments
        if arguments.contains("--show-panel") || arguments.contains("--speed-test") {
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                if arguments.contains("--speed-test") { monitor.startSpeedTest() }
                if arguments.contains("--show-panel") { statusBar?.showPanel() }
            }
        }
    }
}
