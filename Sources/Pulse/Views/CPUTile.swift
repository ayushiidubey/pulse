import SwiftUI

struct CPUModule: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.cpu
        let cores = cpu.reading.cores

        VStack(alignment: .leading, spacing: 0) {
            ModuleHeader(title: "CPU", symbol: "cpu") {
                Chip(text: Self.title(for: cpu.thermalState), color: Self.color(for: cpu.thermalState))
                    .help("Thermal state")
            }
            .padding(.horizontal, Theme.modulePadding)
            .padding(.top, Theme.modulePadding - 2)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    BigValue(value: Format.percent(cpu.reading.total), unit: "%", size: 36, numeric: cpu.reading.total)
                    HStack(spacing: 10) {
                        Legend(title: "User", value: Format.percent(cpu.reading.user) + "%", color: Theme.accent)
                        Legend(title: "System", value: Format.percent(cpu.reading.system) + "%", color: Theme.accentSoft)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    CoreGrid(loads: cores, efficiencyCount: min(monitor.efficiencyCoreCount, cores.count))
                        .padding(.top, 6)
                    HStack(spacing: 5) {
                        Text("Load")
                            .foregroundStyle(.tertiary)
                        Text(cpu.loadAverage.map { String(format: "%.1f", $0) }.joined(separator: "  "))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
                }
            }
            .padding(.horizontal, Theme.modulePadding)
            .padding(.top, 6)

            FlowChart(
                series: [
                    .init(values: cpu.history.values, color: Theme.accent),
                    .init(values: cpu.systemHistory.values, color: Theme.accentSoft),
                ],
                scale: 1,
                tick: monitor.sampleTick
            )
            .frame(height: 56)
            .padding(.top, 4)
        }
        .module()
    }

    private static func title(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Throttling"
        @unknown default: "Unknown"
        }
    }

    private static func color(for state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair: .yellow
        case .serious: Theme.warning
        case .critical: Theme.critical
        @unknown default: .gray
        }
    }
}

private struct Legend: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 10, height: 3)
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11))
    }
}
