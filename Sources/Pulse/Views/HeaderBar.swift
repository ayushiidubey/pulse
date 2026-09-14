import AppKit
import SwiftUI

struct HeaderBar: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(spacing: 12) {
            HeartbeatTrace()
                .frame(width: 76, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text("Pulse")
                    .font(.system(size: 14, weight: .semibold))
                // "MacBook Air (M2, 2022)" → "MacBook Air"; the chip lives in the menu.
                let model = monitor.info.model.split(separator: " (").first.map(String.init) ?? monitor.info.model
                Text("\(model) · \(monitor.info.osVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button(action: openActivityMonitor) {
                Image(systemName: "chart.bar.xaxis")
            }
            .help("Open Activity Monitor")

            OptionsMenu()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.horizontal, Theme.modulePadding)
        .padding(.vertical, 10)
        .module()
    }

    private func openActivityMonitor() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))
    }
}

/// Kept apart from anything sampled live: each update rebuilds the menu's items, which closes an open submenu.
private struct OptionsMenu: View {
    @Environment(SystemMonitor.self) private var monitor
    @Environment(Preferences.self) private var preferences

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuIndicator(.hidden)
        .help("Options")
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
}

/// Frame-by-frame state for the heartbeat: a phase that advances at the current rate, and the last few
/// seconds of the waveform. Kept outside SwiftUI state so it changes without invalidating the view.
final class HeartbeatModel {
    static let sampleCount = 170

    private(set) var samples: [Double] = []
    private var phase = 0.0
    private var beatsPerMinute = 60.0
    private var last: TimeInterval?

    /// The beat lands in the last frame appended.
    private(set) var justBeat = false

    func step(load: Double, at now: TimeInterval) {
        let dt = last.map { min(now - $0, 0.1) } ?? 0
        last = now
        beatsPerMinute += (52 + 118 * min(max(load, 0), 1) - beatsPerMinute) * min(1, dt * 0.6)
        let previous = phase
        phase += dt * beatsPerMinute / 60
        justBeat = Int(previous) != Int(phase)
        samples.append(Self.wave(phase.truncatingRemainder(dividingBy: 1)))
        if samples.count > Self.sampleCount {
            samples.removeFirst(samples.count - Self.sampleCount)
        }
    }

    /// A stylised PQRST complex over one beat. Range roughly −0.3 … 1.
    private static func wave(_ p: Double) -> Double {
        func bump(_ centre: Double, _ width: Double, _ height: Double) -> Double {
            height * exp(-pow((p - centre) / width, 2))
        }
        return bump(0.12, 0.035, 0.16) - bump(0.20, 0.012, 0.12) + bump(0.225, 0.014, 1.0)
            - bump(0.25, 0.012, 0.3) + bump(0.42, 0.05, 0.28)
    }
}

/// A live ECG whose rate follows CPU load: resting when the Mac is idle, racing under load.
struct HeartbeatTrace: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var model = HeartbeatModel()

    var body: some View {
        // Read here rather than passed in, so each sample invalidates only the trace and not the header's menu.
        let load = monitor.cpu.reading.total
        TimelineView(.animation(paused: !DebugFlags.ecgMotion)) { context in
            Canvas { graphics, size in
                model.step(load: load, at: context.date.timeIntervalSinceReferenceDate)
                let samples = model.samples
                guard samples.count > 1 else { return }

                let step = size.width / CGFloat(HeartbeatModel.sampleCount - 1)
                let top = size.height * 0.1, bottom = size.height * 0.84
                func point(_ index: Int) -> CGPoint {
                    let x = size.width - CGFloat(samples.count - 1 - index) * step
                    let y = bottom - CGFloat((samples[index] + 0.3) / 1.3) * (bottom - top)
                    return CGPoint(x: x, y: y)
                }

                var path = Path()
                path.move(to: point(0))
                for index in 1..<samples.count {
                    path.addLine(to: point(index))
                }

                // The trace fades into the past behind it.
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [Theme.accent.opacity(0), Theme.accent]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: 0)
                )
                graphics.stroke(path, with: shading, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                let head = point(samples.count - 1)
                let radius: CGFloat = model.justBeat ? 4 : 2.5
                graphics.fill(Path(ellipseIn: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2)), with: .color(Theme.accent))
            }
        }
    }
}
