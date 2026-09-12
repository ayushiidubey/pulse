import SwiftUI

extension View {
    /// A tile of Liquid Glass. Tiles float as separate pieces of glass over whatever is behind the panel.
    func glassTile() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: PanelView.tileCornerRadius))
    }
}

struct TileHeader<Accessory: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(tint.opacity(0.16), in: .circle)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            accessory()
        }
    }
}

extension TileHeader where Accessory == EmptyView {
    init(title: String, symbol: String, tint: Color) {
        self.init(title: title, symbol: symbol, tint: tint) { EmptyView() }
    }
}

/// A large rounded number whose digits roll when the value changes.
struct BigValue: View {
    let value: String
    let unit: String
    var size: CGFloat = 28
    var numeric: Double = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: numeric))
            Text(unit)
                .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .animation(.snappy(duration: 0.3), value: value)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var color: Color?

    var body: some View {
        HStack(spacing: 6) {
            if let color {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .monospacedDigit()
        }
        .font(.system(size: 11))
        .lineLimit(1)
    }
}

struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(.primary.opacity(0.06), in: .capsule)
    }
}
