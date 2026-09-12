import SwiftUI

/// System colours only, used sparingly: blue for activity, green for battery, orange for upload.
/// Everything else is vibrancy (`.primary`, `.secondary`, `.tertiary`) so the panel adapts to the desktop.
enum Theme {
    static let accent = Color.blue
    static let accentSoft = Color.blue.opacity(0.45)
    static let download = Color.blue
    static let upload = Color.orange
    static let battery = Color.green
    static let warning = Color.orange
    static let critical = Color.red

    static let panelCornerRadius: CGFloat = 30
    static let moduleCornerRadius: CGFloat = 20
    static let modulePadding: CGFloat = 14
    static let spacing: CGFloat = 8
}
