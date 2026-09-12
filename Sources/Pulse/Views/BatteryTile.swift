import SwiftUI

struct BatteryModule: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let battery = monitor.battery {
            let color = Self.color(for: battery)

            HStack(spacing: 14) {
                RingGauge(value: battery.level, color: color, lineWidth: 4) {
                    Image(systemName: Self.symbol(for: battery.state))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(color)
                        .symbolEffect(.pulse, isActive: battery.state == .charging)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: Format.percent(battery.level), unit: "%", size: 26, numeric: battery.level)
                    Text(Self.status(for: battery))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
                    GridRow {
                        MiniStat(title: "Health", value: battery.health.map { Format.percent($0) + "%" })
                        MiniStat(title: "Cycles", value: battery.cycleCount.map { "\($0)" })
                    }
                    GridRow {
                        MiniStat(title: "Temp", value: battery.temperature.map { String(format: "%.0f°", $0) })
                        MiniStat(title: "Power", value: battery.watts.map { String(format: "%.1f W", abs($0)) })
                    }
                }
                .fixedSize()
            }
            .padding(Theme.modulePadding)
            .module()
        }
    }

    private static func status(for battery: BatteryReading) -> String {
        let remaining = battery.minutesRemaining.map { Format.clock(minutes: $0) }
        switch battery.state {
        case .charging: return remaining.map { "\($0) to full" } ?? "Charging"
        case .charged: return "Fully charged"
        case .pluggedIn: return "Plugged in"
        case .discharging: return remaining.map { "\($0) left" } ?? "On battery"
        }
    }

    private static func color(for battery: BatteryReading) -> Color {
        if battery.state == .charging || battery.state == .charged { return Theme.battery }
        if battery.level <= 0.1 { return Theme.critical }
        if battery.level <= 0.2 { return Theme.warning }
        return Theme.battery
    }

    private static func symbol(for state: BatteryReading.State) -> String {
        switch state {
        case .charging: "bolt.fill"
        case .charged, .pluggedIn: "powerplug.fill"
        case .discharging: "battery.75percent"
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
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .gridColumnAlignment(.leading)
    }
}
