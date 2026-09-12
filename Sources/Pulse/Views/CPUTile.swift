import SwiftUI

struct CPUTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let cpu = monitor.cpu
        let cores = cpu.reading.cores
        let efficiencyCount = min(monitor.efficiencyCoreCount, cores.count)

        VStack(alignment: .leading, spacing: 10) {
            TileHeader(title: "CPU", symbol: "cpu", tint: .cyan) {
                Chip(text: Self.title(for: cpu.thermalState), color: Self.color(for: cpu.thermalState))
                    .help("Thermal state")
            }

            HStack(alignment: .bottom) {
                BigValue(value: Format.percent(cpu.reading.total), unit: "%", numeric: cpu.reading.total)
                Spacer()
                VStack(spacing: 3) {
                    StatRow(title: "User", value: Format.percent(cpu.reading.user) + "%", color: .cyan)
                    StatRow(title: "System", value: Format.percent(cpu.reading.system) + "%", color: .indigo)
                }
                .frame(width: 112)
                .padding(.bottom, 4)
            }

            HistoryChart(
                series: [
                    .init(values: cpu.history.values, color: .cyan),
                    .init(values: cpu.systemHistory.values, color: .indigo),
                ],
                scale: 1
            )
            .frame(height: 46)

            HStack(alignment: .bottom, spacing: 14) {
                if efficiencyCount > 0 {
                    CoreGroup(title: "Efficiency", loads: Array(cores.prefix(efficiencyCount)), tint: .teal)
                    CoreGroup(title: "Performance", loads: Array(cores.dropFirst(efficiencyCount)), tint: .cyan)
                } else {
                    CoreGroup(title: "Cores", loads: cores, tint: .cyan)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                    Text("Load average")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .fixedSize()
            }
        }
        .glassTile()
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
        case .serious: .orange
        case .critical: .red
        @unknown default: .gray
        }
    }
}

private struct CoreGroup: View {
    let title: String
    let loads: [Double]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CoreBars(loads: loads, tint: tint)
                .frame(height: 22)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}
