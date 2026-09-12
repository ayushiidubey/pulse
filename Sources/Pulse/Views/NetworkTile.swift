import AppKit
import SwiftUI

struct NetworkModule: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var copiedAddress: String?

    private static let appRowHeight: CGFloat = 22
    private static let appRowCount = 3

    var body: some View {
        let network = monitor.network
        let peak = max(network.downHistory.peak, network.upHistory.peak, 50_000)

        VStack(alignment: .leading, spacing: 0) {
            ModuleHeader(title: Self.title(for: network), symbol: Self.symbol(for: network.connection)) {
                if let wifi = network.wifi {
                    HStack(spacing: 5) {
                        Image(systemName: "wifi", variableValue: wifi.signal)
                        Text([wifi.band, "\(Int(wifi.transmitRate)) Mbps"].compactMap { $0 }.joined(separator: " · "))
                            .monospacedDigit()
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .help("Signal \(wifi.rssi) dBm")
                }
            }
            .padding(.horizontal, Theme.modulePadding)
            .padding(.top, Theme.modulePadding - 2)

            HStack(alignment: .firstTextBaseline, spacing: 18) {
                RateValue(symbol: "arrow.down", rate: network.down, tint: Theme.download)
                RateValue(symbol: "arrow.up", rate: network.up, tint: Theme.upload)
                Spacer(minLength: 0)
                Text("peak \(Format.rate(peak))")
                    .font(.system(size: 10.5))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.modulePadding)
            .padding(.top, 6)

            FlowChart(
                series: [
                    .init(values: network.downHistory.values, color: Theme.download),
                    .init(values: network.upHistory.values, color: Theme.upload, direction: -1),
                ],
                scale: peak * 1.1,
                tick: monitor.sampleTick,
                baselineFraction: 0.5
            )
            .frame(height: 60)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    AddressField(title: "Local", address: network.localAddress, copiedAddress: $copiedAddress)
                    AddressField(title: "Public", address: network.publicAddress, copiedAddress: $copiedAddress)
                }

                SpeedTestRow()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Top apps")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ZStack(alignment: .top) {
                        if monitor.topApps.isEmpty {
                            Text(monitor.hasTrafficSample ? "No app is using the internet" : "Measuring…")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        let busiest = monitor.topApps.first?.total ?? 0
                        VStack(spacing: 2) {
                            ForEach(monitor.topApps) { app in
                                AppTrafficRow(app: app, share: busiest > 0 ? app.total / busiest : 0, icon: monitor.owners.icon(for: app.owner))
                                    .frame(height: Self.appRowHeight)
                            }
                        }
                    }
                    // Fixed height, so the panel doesn't resize as apps come and go.
                    .frame(height: Self.appRowHeight * CGFloat(Self.appRowCount) + 4, alignment: .top)
                }
            }
            .padding(.horizontal, Theme.modulePadding)
            .padding(.top, 8)
            .padding(.bottom, Theme.modulePadding - 4)
        }
        .module()
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

        Inset {
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
                    SpeedFigure(symbol: "arrow.down", mbps: progress.downloadMbps, tint: Theme.download)
                    SpeedFigure(symbol: "arrow.up", mbps: progress.uploadMbps, tint: Theme.upload)
                } else if monitor.speedTestFailed {
                    Text("Couldn't finish the test")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if let result = monitor.speedTestResult {
                    SpeedFigure(symbol: "arrow.down", mbps: result.downloadMbps, tint: Theme.download)
                    SpeedFigure(symbol: "arrow.up", mbps: result.uploadMbps, tint: Theme.upload)
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
            .frame(height: 24)
        }
    }

    private static func color(forRating rating: String) -> Color {
        switch rating.lowercased() {
        case "high": .green
        case "medium": .yellow
        default: Theme.warning
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
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText(value: mbps))
            Text("Mbps")
                .font(.system(size: 9, weight: .medium))
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
            BigValue(value: quantity.value, unit: quantity.unit + "/s", size: 22, numeric: rate)
        }
    }
}

private struct AddressField: View {
    let title: String
    let address: String?
    @Binding var copiedAddress: String?

    var body: some View {
        Inset {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
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
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Copy \(title.lowercased()) IP address")
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppTrafficRow: View {
    let app: AppTraffic
    /// This app's traffic relative to the busiest app, for the bar behind the row.
    let share: Double
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
                        .background(.fill.secondary, in: .rect(cornerRadius: 4))
                }
            }
            .frame(width: 16, height: 16)

            Text(app.owner.name)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer(minLength: 6)
            RateLabel(symbol: "arrow.down", rate: app.down, tint: Theme.download)
            RateLabel(symbol: "arrow.up", rate: app.up, tint: Theme.upload)
        }
        .padding(.horizontal, 6)
        .background(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.accent.opacity(0.14))
                    .frame(width: max(proxy.size.width * CGFloat(share), 24))
            }
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
