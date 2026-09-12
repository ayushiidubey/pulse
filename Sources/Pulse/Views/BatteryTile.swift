import SwiftUI

struct BatteryTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let battery = monitor.battery {
            let tint = Self.tint(for: battery)

            HStack(spacing: 12) {
                RingGauge(value: battery.level, tint: tint) {
                    Image(systemName: Self.symbol(for: battery.state))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: Format.percent(battery.level), unit: "%", size: 22, numeric: battery.level)
                    Text(Self.status(for: battery))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
                    GridRow {
                        MiniStat(title: "Health", value: battery.health.map { Format.percent($0) + "%" })
                        MiniStat(title: "Cycles", value: battery.cycleCount.map { "\($0)" })
                    }
                    GridRow {
                        MiniStat(title: "Temp", value: battery.temperature.map { String(format: "%.0f°C", $0) })
                        MiniStat(title: "Power", value: battery.watts.map { String(format: "%.1f W", abs($0)) })
                    }
                }
                .fixedSize()
            }
            .glassTile()
        }
    }

    private static func status(for battery: BatteryReading) -> String {
        let remaining = battery.minutesRemaining.map { Format.clock(minutes: $0) }
        switch battery.state {
        case .charging: return remaining.map { "Charging · \($0) to full" } ?? "Charging"
        case .charged: return "Fully charged"
        case .pluggedIn: return "Plugged in, not charging"
        case .discharging: return remaining.map { "On battery · \($0) left" } ?? "On battery"
        }
    }

    private static func tint(for battery: BatteryReading) -> Color {
        if battery.state == .charging || battery.state == .charged { return .green }
        if battery.level <= 0.1 { return .red }
        if battery.level <= 0.2 { return .orange }
        return .green
    }

    private static func symbol(for state: BatteryReading.State) -> String {
        switch state {
        case .charging: "bolt.fill"
        case .charged, .pluggedIn: "powerplug.fill"
        case .discharging: "leaf.fill"
        }
    }
}

private struct MiniStat: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.tertiary)
            Text(value ?? "—")
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .gridColumnAlignment(.leading)
    }
}
