import AppKit
import SwiftUI

struct HeaderBar: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing), in: .circle)

            VStack(alignment: .leading, spacing: 1) {
                Text("Pulse")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(monitor.info.model) · \(monitor.info.osVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Button(action: openActivityMonitor) {
                Image(systemName: "chart.bar.xaxis")
            }
            .help("Open Activity Monitor")

            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .help("Options")
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .padding(8)
        .glassEffect(.regular, in: .capsule)
    }

    @ViewBuilder
    private var menuContent: some View {
        Picker("Menu Bar Shows", selection: Binding(get: { preferences.menuBarMode }, set: { preferences.setMenuBarMode($0) })) {
            ForEach(MenuBarMode.allCases) { mode in
                Label(mode.title, systemImage: mode.symbol)
                    .tag(mode)
            }
        }
        Toggle("Open at Login", isOn: Binding(get: { preferences.launchesAtLogin }, set: { preferences.setLaunchesAtLogin($0) }))
        Divider()
        Text("\(monitor.info.chip) · up \(Format.uptime(since: monitor.info.bootDate))")
        Button("Quit Pulse") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}
