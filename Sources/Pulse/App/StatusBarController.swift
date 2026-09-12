import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let monitor: SystemMonitor
    private let preferences: Preferences
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel = GlassPanel()

    private var anchor: NSRect = .zero
    private var isClosing = false
    private var eventMonitors: [Any] = []
    private var resignObserver: (any NSObjectProtocol)?

    init(monitor: SystemMonitor, preferences: Preferences) {
        self.monitor = monitor
        self.preferences = preferences
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePanel)
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Pulse")
        }
        monitor.onSample = { [weak self] in self?.renderStatusItem() }
        preferences.onMenuBarModeChange = { [weak self] in self?.renderStatusItem() }
        renderStatusItem()
    }

    private func renderStatusItem() {
        statusItem.button?.image = MenuBarRenderer.image(for: preferences.menuBarMode, monitor: monitor)
    }

    func showPanel() {
        if !panel.isVisible { openPanel() }
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    // MARK: Panel lifecycle

    private func openPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        monitor.setPanelVisible(true)

        // The SwiftUI tree is built per session and released on close, so nothing renders while hidden.
        let root = PanelView(
            onSizeChange: { [weak self] size in self?.resizePanel(to: size) },
            close: { [weak self] in self?.closePanel() }
        )
        .environment(monitor)
        .environment(preferences)
        let hostingView = NSHostingView(rootView: root)
        panel.contentView = hostingView
        panel.setFrame(frame(for: hostingView.fittingSize), display: false)

        panel.alphaValue = 0
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            self.panel.animator().alphaValue = 1
        }
        installDismissTriggers()
    }

    private func closePanel() {
        guard panel.isVisible, !isClosing else { return }
        isClosing = true
        removeDismissTriggers()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            self.panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { self.finishClosing() }
        })
    }

    private func finishClosing() {
        panel.orderOut(nil)
        panel.contentView = nil
        isClosing = false
        monitor.setPanelVisible(false)
    }

    private func resizePanel(to size: CGSize) {
        guard panel.isVisible, !isClosing else { return }
        let target = frame(for: size)
        guard target.size != panel.frame.size else { return }
        panel.setFrame(target, display: true)
    }

    /// Centres the panel under the status item, keeps it on screen, and leaves a small gap below the menu bar.
    private func frame(for size: CGSize) -> NSRect {
        let visible = (statusItem.button?.window?.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        let inset = PanelView.outerPadding
        let width = size.width.rounded(.up), height = size.height.rounded(.up)
        var x = anchor.midX - width / 2
        x = min(max(x, visible.minX - inset + 6), visible.maxX - width + inset - 6)
        let top = anchor.minY + inset - 6
        return NSRect(x: x.rounded(), y: (top - height).rounded(), width: width, height: height)
    }

    // MARK: Dismissal

    private func installDismissTriggers() {
        removeDismissTriggers()
        if let clickOutside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { _ in
            MainActor.assumeIsolated { self.closePanel() }
        }) {
            eventMonitors.append(clickOutside)
        }
        if let escape = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self.closePanel() }
            return nil
        }) {
            eventMonitors.append(escape)
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { self.closePanel() }
        }
    }

    private func removeDismissTriggers() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors.removeAll()
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}
