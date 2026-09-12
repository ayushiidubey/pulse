import SwiftUI

struct MemoryModule: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ModuleHeader(title: "Memory", symbol: "memorychip") {
                if let memory = monitor.memory {
                    RingGauge(value: memory.usedFraction, color: Theme.accent, lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .overlay {
                            Circle()
                                .fill(Self.color(for: memory.pressure))
                                .frame(width: 5, height: 5)
                        }
                        .help("Memory pressure: \(Self.title(for: memory.pressure))")
                }
            }

            if let memory = monitor.memory {
                let used = Format.memory(memory.used)
                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: used.value, unit: used.unit, size: 26, numeric: Double(memory.used))
                    Text("of \(Format.memory(memory.total).compactText)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SegmentedBar(segments: [
                    .init(fraction: Self.fraction(memory.app, of: memory), color: Theme.accent),
                    .init(fraction: Self.fraction(memory.wired, of: memory), color: Theme.accent.opacity(0.6)),
                    .init(fraction: Self.fraction(memory.compressed, of: memory), color: Theme.accent.opacity(0.32)),
                ])

                VStack(spacing: 4) {
                    StatRow(title: "App", value: Format.memory(memory.app).text, color: Theme.accent)
                    StatRow(title: "Wired", value: Format.memory(memory.wired).text, color: Theme.accent.opacity(0.6))
                    StatRow(title: "Compressed", value: Format.memory(memory.compressed).text, color: Theme.accent.opacity(0.32))
                    StatRow(title: "Swap", value: Format.memory(memory.swapUsed).text, color: .clear)
                }
            }
        }
        .padding(Theme.modulePadding)
        .module()
    }

    private static func fraction(_ bytes: UInt64, of memory: MemoryReading) -> Double {
        memory.total > 0 ? Double(bytes) / Double(memory.total) : 0
    }

    private static func title(for pressure: MemoryPressure) -> String {
        switch pressure {
        case .normal: "Normal"
        case .warning: "Elevated"
        case .critical: "Critical"
        }
    }

    private static func color(for pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: .green
        case .warning: .yellow
        case .critical: Theme.critical
        }
    }
}

struct DiskModule: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let disk = monitor.disk

        VStack(alignment: .leading, spacing: 10) {
            ModuleHeader(title: "Disk", symbol: "internaldrive") {
                if let volume = disk.volume {
                    RingGauge(value: volume.usedFraction, color: .primary.opacity(0.7), lineWidth: 3)
                        .frame(width: 20, height: 20)
                        .help("\(Format.percent(volume.usedFraction))% used")
                }
            }

            if let volume = disk.volume {
                let free = Format.bytes(volume.available)
                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: free.value, unit: free.unit, size: 26, numeric: volume.available)
                    Text("free of \(Format.bytes(volume.total).compactText)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SegmentedBar(segments: [.init(fraction: volume.usedFraction, color: .primary.opacity(0.7))])

                VStack(spacing: 4) {
                    StatRow(title: "Read", value: Format.rate(disk.readRate), color: .primary.opacity(0.7))
                    StatRow(title: "Write", value: Format.rate(disk.writeRate), color: .primary.opacity(0.35))
                    StatRow(title: "Used", value: Format.bytes(volume.total - volume.available).text, color: .clear)
                    StatRow(title: volume.name, value: "", color: .clear)
                }
            }
        }
        .padding(Theme.modulePadding)
        .module()
    }
}
