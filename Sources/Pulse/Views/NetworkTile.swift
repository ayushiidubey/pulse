import AppKit
import SwiftUI

struct NetworkTile: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var copiedAddress: String?

    private static let appRowHeight: CGFloat = 20
    private static let appRowCount = 3

    var body: some View {
        let network = monitor.network
        let peak = max(network.downHistory.peak, network.upHistory.peak, 50_000)

        VStack(alignment: .leading, spacing: 8) {
            TileHeader(title: Self.title(for: network), symbol: Self.symbol(for: network.connection), tint: .blue) {
                if let wifi = network.wifi {
                    HStack(spacing: 5) {
                        Image(systemName: "wifi", variableValue: wifi.signal)
                        Text([wifi.band, "\(Int(wifi.transmitRate)) Mbps"].compactMap { $0 }.joined(separator: " · "))
                            .monospacedDigit()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .help("Signal \(wifi.rssi) dBm")
                }
            }

            HStack(spacing: 22) {
                RateValue(symbol: "arrow.down", rate: network.down, tint: .blue)
                RateValue(symbol: "arrow.up", rate: network.up, tint: .pink)
                Spacer(minLength: 0)
            }

            HistoryChart(
                series: [
                    .init(values: network.downHistory.values, color: .blue),
                    .init(values: network.upHistory.values, color: .pink, isMirrored: true),
                ],
                scale: peak * 1.15
            )
            .frame(height: 50)
            // Top leading: the newest samples, and so the most recent peaks, sit at the trailing edge.
            .overlay(alignment: .topLeading) {
                Text(Format.rate(peak))
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                AddressField(title: "Local", address: network.localAddress, copiedAddress: $copiedAddress)
                AddressField(title: "Public", address: network.publicAddress, copiedAddress: $copiedAddress)
            }

            SpeedTestRow()

            Divider()
                .opacity(0.6)

            VStack(alignment: .leading, spacing: 4) {
                Text("Top apps")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
                ZStack(alignment: .top) {
                    if monitor.topApps.isEmpty {
                        Text(monitor.hasTrafficSample ? "No app is using the internet" : "Measuring…")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    VStack(spacing: 0) {
                        ForEach(monitor.topApps) { app in
                            AppTrafficRow(app: app, icon: monitor.owners.icon(for: app.owner))
                                .frame(height: Self.appRowHeight)
                        }
                    }
                }
                // Fixed height, so the panel doesn't resize as apps come and go.
                .frame(height: Self.appRowHeight * CGFloat(Self.appRowCount), alignment: .top)
            }
        }
        .glassTile()
        .task(id: copiedAddress) {
            guard copiedAddress != nil else { return }
            try? await Task.sleep(for: .seconds(1.2))
            copiedAddress = nil
        }
    }

    private static func title(for network: SystemMonitor.NetworkState) -> String {
        switch network.connection {
        case .wifi: network.wifi?.ssid ?? "Wi-Fi"
        case .ethernet: "Ethernet"
        case .cellular: "Cellular"
        case .other: network.interfaceName ?? "Network"
        case .offline: "Offline"
        }
    }

    private static func symbol(for connection: SystemMonitor.Connection) -> String {
        switch connection {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .cellular: "antenna.radiowaves.left.and.right"
        case .other: "network"
        case .offline: "wifi.slash"
        }
    }
}

private struct SpeedTestRow: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let isRunning = monitor.speedTestProgress != nil

        HStack(spacing: 8) {
            Button {
                if isRunning {
                    monitor.cancelSpeedTest()
                } else {
                    monitor.startSpeedTest()
                }
            } label: {
                if isRunning {
                    Label("Stop", systemImage: "stop.fill")
                } else {
                    Label(monitor.speedTestResult == nil ? "Speed Test" : "Test Again", systemImage: "gauge.with.needle")
                }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .disabled(monitor.network.connection == .offline)
            .help("Measure download and upload speed with Apple's networkQuality")

            Spacer(minLength: 4)

            if let progress = monitor.speedTestProgress {
                ProgressView()
                    .controlSize(.mini)
                SpeedFigure(symbol: "arrow.down", mbps: progress.downloadMbps, tint: .blue)
                SpeedFigure(symbol: "arrow.up", mbps: progress.uploadMbps, tint: .pink)
            } else if monitor.speedTestFailed {
                Text("Couldn't finish the test")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else if let result = monitor.speedTestResult {
                SpeedFigure(symbol: "arrow.down", mbps: result.downloadMbps, tint: .blue)
                SpeedFigure(symbol: "arrow.up", mbps: result.uploadMbps, tint: .pink)
                if let rating = result.responsivenessRating {
                    Chip(text: rating, color: Self.color(forRating: rating))
                        .help(Self.details(for: result))
                }
            } else {
                Text("Tests against Apple's servers")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: 26)
    }

    private static func color(forRating rating: String) -> Color {
        switch rating.lowercased() {
        case "high": .green
        case "medium": .yellow
        default: .orange
        }
    }

    private static func details(for result: SpeedTestResult) -> String {
        var parts = ["Responsiveness"]
        if let rpm = result.responsivenessRPM { parts.append("\(Int(rpm.rounded())) RPM") }
        if let latency = result.idleLatencyMilliseconds { parts.append("idle latency \(Int(latency.rounded())) ms") }
        parts.append("tested \(result.date.formatted(.relative(presentation: .named)))")
        return parts.joined(separator: " · ")
    }
}

private struct SpeedFigure: View {
    let symbol: String
    let mbps: Double
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(tint)
            Text(Format.megabits(mbps))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: mbps))
            Text("Mbps")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .animation(.snappy(duration: 0.25), value: mbps)
        .fixedSize()
    }
}

private struct RateValue: View {
    let symbol: String
    let rate: Double
    let tint: Color

    var body: some View {
        let quantity = Format.bytes(rate)
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            BigValue(value: quantity.value, unit: quantity.unit + "/s", size: 20, numeric: rate)
        }
    }
}

private struct AddressField: View {
    let title: String
    let address: String?
    @Binding var copiedAddress: String?

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(address ?? "—")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            if let address {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(address, forType: .string)
                    copiedAddress = address
                } label: {
                    Image(systemName: copiedAddress == address ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .help("Copy \(title.lowercased()) IP address")
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppTrafficRow: View {
    let app: AppTraffic
    let icon: NSImage?

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.primary.opacity(0.08), in: .rect(cornerRadius: 4))
                }
            }
            .frame(width: 16, height: 16)

            Text(app.owner.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 6)
            RateLabel(symbol: "arrow.down", rate: app.down, tint: .blue)
            RateLabel(symbol: "arrow.up", rate: app.up, tint: .pink)
        }
    }
}

private struct RateLabel: View {
    let symbol: String
    let rate: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)
            Text(Format.rate(rate))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .frame(width: 76, alignment: .trailing)
    }
}
