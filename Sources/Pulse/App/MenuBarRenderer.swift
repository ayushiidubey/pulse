import AppKit

/// Draws the status item as a template image, so the system tints it for the menu bar's appearance.
/// Widths are fixed per mode so neighbouring menu bar items never shift as numbers change.
enum MenuBarRenderer {
    static func image(for mode: MenuBarMode, monitor: SystemMonitor) -> NSImage {
        let image = switch mode {
        case .cpu:
            cpuImage(history: monitor.cpu.history.values.suffix(8), total: monitor.cpu.reading.total)
        case .memory:
            symbolImage(named: mode.symbol, text: Format.percent(monitor.memory?.usedFraction ?? 0) + "%")
        case .network:
            networkImage(down: monitor.network.down, up: monitor.network.up)
        }
        image.isTemplate = true
        return image
    }

    private static let valueFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private static let percentWidth = ceil(("100%" as NSString).size(withAttributes: [.font: valueFont]).width)

    private static func cpuImage(history: ArraySlice<Double>, total: Double) -> NSImage {
        let bars = 8
        let barWidth: CGFloat = 2.5, gap: CGFloat = 1.5, graphHeight: CGFloat = 12
        let graphWidth = CGFloat(bars) * barWidth + CGFloat(bars - 1) * gap
        let values = Array(repeating: 0.0, count: max(bars - history.count, 0)) + history
        let text = Format.percent(total) + "%"

        return NSImage(size: NSSize(width: graphWidth + 5 + percentWidth, height: 18), flipped: false) { rect in
            let bottom = ((rect.height - graphHeight) / 2).rounded()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * (barWidth + gap)
                NSColor.black.withAlphaComponent(0.22).setFill()
                NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barWidth, height: graphHeight), xRadius: 1, yRadius: 1).fill()
                NSColor.black.setFill()
                let height = max(1.5, graphHeight * min(max(value, 0), 1))
                NSBezierPath(roundedRect: NSRect(x: x, y: bottom, width: barWidth, height: height), xRadius: 1, yRadius: 1).fill()
            }
            drawTrailing(text, in: rect)
            return true
        }
    }

    private static func symbolImage(named symbol: String, text: String) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
        let glyphSize = glyph?.size ?? .zero

        return NSImage(size: NSSize(width: glyphSize.width + 4 + percentWidth, height: 18), flipped: false) { rect in
            glyph?.draw(in: NSRect(x: 0, y: (rect.height - glyphSize.height) / 2, width: glyphSize.width, height: glyphSize.height))
            drawTrailing(text, in: rect)
            return true
        }
    }

    private static func networkImage(down: Double, up: Double) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 9.5, weight: .semibold)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.black, .paragraphStyle: paragraph]
        let width = ceil(("↓ 000 KB/s" as NSString).size(withAttributes: attributes).width) + 2
        let lines = ["↑ " + Format.rate(up), "↓ " + Format.rate(down)]

        return NSImage(size: NSSize(width: width, height: 20), flipped: true) { rect in
            (lines[0] as NSString).draw(in: NSRect(x: 0, y: -0.5, width: rect.width, height: 11), withAttributes: attributes)
            (lines[1] as NSString).draw(in: NSRect(x: 0, y: 9, width: rect.width, height: 11), withAttributes: attributes)
            return true
        }
    }

    private static func drawTrailing(_ text: String, in rect: NSRect) {
        let string = NSAttributedString(string: text, attributes: [.font: valueFont, .foregroundColor: NSColor.black])
        let size = string.size()
        string.draw(at: NSPoint(x: rect.width - size.width, y: ((rect.height - size.height) / 2).rounded()))
    }
}
