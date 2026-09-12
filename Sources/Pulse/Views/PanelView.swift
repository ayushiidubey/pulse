import SwiftUI

struct PanelView: View {
    /// Transparent margin around the glass so its shadow and lensing aren't clipped by the window edge.
    static let outerPadding: CGFloat = 16
    static let width: CGFloat = 392
    static let tileCornerRadius: CGFloat = 24
    static let spacing: CGFloat = 10

    let onSizeChange: (CGSize) -> Void
    let close: () -> Void

    @Environment(SystemMonitor.self) private var monitor
    @State private var hasAppeared = false

    var body: some View {
        // Container spacing below the tile gap keeps tiles as separate pieces of glass that share one sampling pass.
        GlassEffectContainer(spacing: 4) {
            VStack(spacing: Self.spacing) {
                HeaderBar()
                CPUTile()
                HStack(spacing: Self.spacing) {
                    MemoryTile()
                    DiskTile()
                }
                .fixedSize(horizontal: false, vertical: true)
                NetworkTile()
                if monitor.battery != nil {
                    BatteryTile()
                }
            }
        }
        .frame(width: Self.width)
        .padding(Self.outerPadding)
        .fixedSize()
        .scaleEffect(hasAppeared ? 1 : 0.96, anchor: .top)
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
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
