import SwiftUI

struct PanelView: View {
    /// Transparent margin around the panel for its shadow.
    static let outerPadding: CGFloat = 24
    static let width: CGFloat = 396

    let onSizeChange: (CGSize) -> Void
    let close: () -> Void

    @Environment(SystemMonitor.self) private var monitor
    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: Theme.spacing) {
            HeaderBar()
                .moduleReveal(0)
            CPUModule()
                .moduleReveal(1)
            HStack(spacing: Theme.spacing) {
                MemoryModule()
                DiskModule()
            }
            .fixedSize(horizontal: false, vertical: true)
            .moduleReveal(2)
            NetworkModule()
                .moduleReveal(3)
            if monitor.battery != nil {
                BatteryModule()
                    .moduleReveal(4)
            }
        }
        .padding(Theme.spacing)
        .frame(width: Self.width)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.panelCornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 22, y: 10)
        .padding(Self.outerPadding)
        .fixedSize()
        .scaleEffect(hasAppeared ? 1 : 0.97, anchor: .top)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                hasAppeared = true
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            onSizeChange(size)
        }
    }
}
