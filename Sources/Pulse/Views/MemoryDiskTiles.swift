import SwiftUI

struct MemoryTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TileHeader(title: "Memory", symbol: "memorychip", tint: .blue) {
                if let memory = monitor.memory {
                    Circle()
                        .fill(Self.color(for: memory.pressure))
                        .frame(width: 8, height: 8)
                        .help("Memory pressure: \(Self.title(for: memory.pressure))")
                }
            }

            if let memory = monitor.memory {
                let used = Format.memory(memory.used)
                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: used.value, unit: used.unit, size: 24, numeric: Double(memory.used))
                    Text("used of \(Format.memory(memory.total).compactText)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SegmentedBar(segments: [
                    .init(fraction: Self.fraction(memory.app, of: memory), color: .blue),
                    .init(fraction: Self.fraction(memory.wired, of: memory), color: .orange),
                    .init(fraction: Self.fraction(memory.compressed, of: memory), color: .purple),
                ])

                VStack(spacing: 3) {
                    StatRow(title: "App", value: Format.memory(memory.app).text, color: .blue)
                    StatRow(title: "Wired", value: Format.memory(memory.wired).text, color: .orange)
                    StatRow(title: "Compressed", value: Format.memory(memory.compressed).text, color: .purple)
                    StatRow(title: "Swap", value: Format.memory(memory.swapUsed).text, color: .clear)
                }
            }
        }
        .glassTile()
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
        case .critical: .red
        }
    }
}

struct DiskTile: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let disk = monitor.disk

        VStack(alignment: .leading, spacing: 8) {
            TileHeader(title: "Disk", symbol: "internaldrive", tint: .mint)

            if let volume = disk.volume {
                let free = Format.bytes(volume.available)
                VStack(alignment: .leading, spacing: 0) {
                    BigValue(value: free.value, unit: free.unit, size: 24, numeric: volume.available)
                    Text("free of \(Format.bytes(volume.total).compactText)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                SegmentedBar(segments: [.init(fraction: volume.usedFraction, color: .mint)])

                VStack(spacing: 3) {
                    StatRow(title: "Read", value: Format.rate(disk.readRate), color: .mint)
                    StatRow(title: "Write", value: Format.rate(disk.writeRate), color: .teal)
                    StatRow(title: "Used", value: Format.bytes(volume.total - volume.available).text, color: .clear)
                    StatRow(title: "Volume", value: volume.name, color: .clear)
                }
            }
        }
        .glassTile()
    }
}
