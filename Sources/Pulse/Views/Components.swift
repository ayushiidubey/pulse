import SwiftUI

extension View {
    /// A translucent module inside the glass panel, in the manner of Control Center. Content is clipped
    /// to the module so charts can run edge to edge; modules do their own padding.
    func module() -> some View {
        frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.fill.quaternary, in: .rect(cornerRadius: Theme.moduleCornerRadius, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Theme.moduleCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.moduleCornerRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            }
    }

    /// Modules enter one after another when the panel opens.
    func moduleReveal(_ index: Int) -> some View {
        modifier(ModuleReveal(index: index))
    }
}

private struct ModuleReveal: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.03 + Double(index) * 0.045)) {
                    shown = true
                }
            }
    }
}

struct ModuleHeader<Accessory: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            accessory()
        }
    }
}

extension ModuleHeader where Accessory == EmptyView {
    init(title: String, symbol: String) {
        self.init(title: title, symbol: symbol) { EmptyView() }
    }
}

/// A large number whose digits roll when the value changes.
struct BigValue: View {
    let value: String
    let unit: String
    var size: CGFloat = 32
    var numeric: Double = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .semibold))
                .tracking(-size * 0.02)
                .monospacedDigit()
                .contentTransition(.numericText(value: numeric))
                .animation(.snappy(duration: 0.3), value: value)
            // The unit swaps instantly; cross-fading it leaves "B/s" and "KB/s" ghosting over each other.
            Text(unit)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(.secondary)
                .transaction { $0.animation = nil }
        }
        .lineLimit(1)
    }
}

struct StatRow: View {
    let title: String
    let value: String
    var color: Color?

    var body: some View {
        HStack(spacing: 7) {
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
        .font(.system(size: 11.5))
        .lineLimit(1)
    }
}

struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(.fill.tertiary, in: .capsule)
    }
}

/// A soft inset inside a module, for secondary information.
struct Inset<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.fill.tertiary, in: .rect(cornerRadius: 11, style: .continuous))
    }
}
