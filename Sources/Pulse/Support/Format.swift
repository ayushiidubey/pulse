import Foundation

enum Format {
    struct Quantity {
        let value: String
        let unit: String
        var text: String { "\(value) \(unit)" }
        /// "16 GB" rather than "16.0 GB", for fixed totals where the decimal adds nothing.
        var compactText: String { (value.hasSuffix(".0") ? String(value.dropLast(2)) : value) + " \(unit)" }
    }

    /// Decimal units (1 KB = 1000 B), matching Finder and network tools.
    static func bytes(_ bytes: Double) -> Quantity {
        scaled(bytes, base: 1000)
    }

    /// Binary units labelled GB, matching Activity Monitor's memory figures.
    static func memory(_ bytes: UInt64) -> Quantity {
        scaled(Double(bytes), base: 1024)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        "\(bytes(bytesPerSecond).text)/s"
    }

    /// "112", "48.6", "3.25": about three significant figures.
    static func megabits(_ mbps: Double) -> String {
        String(format: mbps >= 100 ? "%.0f" : mbps >= 10 ? "%.1f" : "%.2f", max(mbps, 0))
    }

    static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))"
    }

    /// "2:07" for 127 minutes.
    static func clock(minutes: Int) -> String {
        String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    static func uptime(since date: Date, now: Date = .now) -> String {
        let minutes = max(Int(now.timeIntervalSince(date) / 60), 0)
        let days = minutes / 1440, hours = (minutes % 1440) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

    private static func scaled(_ raw: Double, base: Double) -> Quantity {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(raw, 0)
        var index = 0
        while value >= base * 0.9995, index < units.count - 1 {
            value /= base
            index += 1
        }
        let digits = index == 0 || value >= 100 ? 0 : 1
        return Quantity(value: String(format: "%.\(digits)f", value), unit: units[index])
    }
}
