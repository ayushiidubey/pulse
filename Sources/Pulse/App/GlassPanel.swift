import AppKit

/// A borderless, fully transparent panel. All visible chrome comes from the SwiftUI glass inside it,
/// so each tile refracts whatever is on the desktop behind it.
final class GlassPanel: NSPanel {
    convenience init() {
        self.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Borderless panels may sit flush against the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
