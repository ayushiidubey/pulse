import SwiftUI

/// Smoothed area chart of recent samples, newest at the trailing edge. Drawn in a single Canvas pass.
struct HistoryChart: View {
    struct Series {
        var values: [Double]
        var color: Color
        /// Drawn downward from the centre line, so upload can sit under download.
        var isMirrored = false
    }

    let series: [Series]
    /// The value that reaches the top of the chart (or the top and bottom edges when mirrored).
    let scale: Double
    var capacity = 60

    var body: some View {
        Canvas { context, size in
            let hasMirror = series.contains { $0.isMirrored }
            let baseline = hasMirror ? (size.height / 2).rounded() : size.height

            var grid = Path()
            for fraction in [0.25, 0.5, 0.75] {
                let y = (size.height * fraction).rounded() + 0.5
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.primary.opacity(0.07)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

            for item in series where item.values.count > 1 {
                let span = item.isMirrored ? -(size.height - baseline) : baseline
                let points = Self.points(item.values, capacity: capacity, width: size.width, baseline: baseline, span: span, scale: scale)
                let line = Self.smoothPath(through: points)

                var area = line
                area.addLine(to: CGPoint(x: points[points.count - 1].x, y: baseline))
                area.addLine(to: CGPoint(x: points[0].x, y: baseline))
                area.closeSubpath()

                context.fill(area, with: .linearGradient(
                    Gradient(colors: [item.color.opacity(0.45), item.color.opacity(0.04)]),
                    startPoint: CGPoint(x: 0, y: baseline - span),
                    endPoint: CGPoint(x: 0, y: baseline)
                ))
                context.stroke(line, with: .color(item.color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private static func points(_ values: [Double], capacity: Int, width: CGFloat, baseline: CGFloat, span: CGFloat, scale: Double) -> [CGPoint] {
        let step = width / CGFloat(max(capacity - 1, 1))
        let start = width - CGFloat(values.count - 1) * step
        return values.enumerated().map { index, value in
            let fraction = scale > 0 ? min(max(value / scale, 0), 1) : 0
            return CGPoint(x: start + CGFloat(index) * step, y: baseline - CGFloat(fraction) * span)
        }
    }

    private static func smoothPath(through points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for index in 1..<points.count {
            let previous = points[index - 1], current = points[index]
            path.addQuadCurve(to: CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2), control: previous)
        }
        path.addLine(to: points[points.count - 1])
        return path
    }
}

/// One vertical bar per core.
struct CoreBars: View {
    let loads: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard !loads.isEmpty else { return }
            let gap: CGFloat = 3
            let width = (size.width - gap * CGFloat(loads.count - 1)) / CGFloat(loads.count)
            let radius = min(width / 2, 3)
            for (index, load) in loads.enumerated() {
                let x = CGFloat(index) * (width + gap)
                let track = CGRect(x: x, y: 0, width: width, height: size.height)
                context.fill(Path(roundedRect: track, cornerRadius: radius, style: .continuous), with: .color(.primary.opacity(0.08)))
                let height = max(size.height * CGFloat(min(max(load, 0), 1)), 2)
                let fill = CGRect(x: x, y: size.height - height, width: width, height: height)
                context.fill(Path(roundedRect: fill, cornerRadius: radius, style: .continuous), with: .color(tint))
            }
        }
    }
}

/// A capsule track filled left to right by consecutive segments.
struct SegmentedBar: View {
    struct Segment {
        let fraction: Double
        let color: Color
    }

    let segments: [Segment]

    var body: some View {
        Canvas { context, size in
            let track = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.height / 2, style: .continuous)
            context.fill(track, with: .color(.primary.opacity(0.08)))
            context.clip(to: track)
            var x: CGFloat = 0
            for segment in segments {
                let width = size.width * CGFloat(min(max(segment.fraction, 0), 1))
                guard width > 0.5 else { continue }
                context.fill(Path(CGRect(x: x, y: 0, width: max(width - 1.5, 0.5), height: size.height)), with: .color(segment.color))
                x += width
            }
        }
        .frame(height: 8)
    }
}

struct RingGauge<Label: View>: View {
    let value: Double
    let tint: Color
    var lineWidth: CGFloat = 5
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label()
        }
        .padding(lineWidth / 2)
    }
}
