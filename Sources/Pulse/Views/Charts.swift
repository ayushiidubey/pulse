import SwiftUI

/// Remembers when the latest sample arrived, so a chart can slide smoothly between samples.
/// Kept outside SwiftUI state: it changes without invalidating the view.
final class SampleClock {
    private(set) var tick = -1
    private(set) var arrived: TimeInterval = 0

    /// 1 the moment a sample lands (the trace sits one step to the right), easing to 0 a second later.
    func slide(tick: Int, now: TimeInterval) -> CGFloat {
        if tick != self.tick {
            // The first sample after opening shouldn't slide in from nowhere.
            arrived = self.tick < 0 ? now - 1 : now
            self.tick = tick
        }
        return CGFloat(max(0, 1 - (now - arrived)))
    }
}

/// Traces of recent samples, newest at the trailing edge, drawn edge to edge in one Canvas pass and
/// scrolling continuously so the chart flows instead of jumping once a second.
struct FlowChart: View {
    struct Series {
        var values: [Double]
        var color: Color
        /// +1 draws upward from the baseline, −1 downward.
        var direction: CGFloat = 1
    }

    let series: [Series]
    let scale: Double
    /// The monitor's sample counter; each change slides the chart along by one step.
    let tick: Int
    var capacity = 60
    /// 1 puts the baseline at the bottom, 0.5 in the middle.
    var baselineFraction: CGFloat = 1

    @State private var clock = SampleClock()

    var body: some View {
        TimelineView(.animation(paused: !DebugFlags.chartMotion)) { context in
            Canvas { graphics, size in
                let slide = clock.slide(tick: tick, now: context.date.timeIntervalSinceReferenceDate)
                let step = size.width / CGFloat(max(capacity - 1, 1))
                let baseline = size.height * baselineFraction

                for item in series where item.values.count > 1 && scale > 0 {
                    let extent = item.direction > 0 ? baseline : size.height - baseline
                    let points = item.values.enumerated().map { index, value in
                        let fraction = min(max(value / scale, 0), 1)
                        return CGPoint(
                            x: size.width - CGFloat(item.values.count - 1 - index) * step + slide * step,
                            y: baseline - item.direction * CGFloat(fraction) * extent
                        )
                    }
                    let line = Self.smoothPath(through: points)

                    var area = line
                    area.addLine(to: CGPoint(x: points[points.count - 1].x, y: baseline))
                    area.addLine(to: CGPoint(x: points[0].x, y: baseline))
                    area.closeSubpath()
                    graphics.fill(area, with: .linearGradient(
                        Gradient(colors: [item.color.opacity(0.28), item.color.opacity(0.02)]),
                        startPoint: CGPoint(x: 0, y: baseline - item.direction * extent),
                        endPoint: CGPoint(x: 0, y: baseline)
                    ))
                    graphics.stroke(line, with: .color(item.color), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                }
            }
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

/// One cell per core; opacity is load.
struct CoreGrid: View {
    let loads: [Double]
    let efficiencyCount: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(loads.indices, id: \.self) { index in
                let isEfficiency = index < efficiencyCount
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.fill.secondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Theme.accent)
                            .opacity(0.08 + 0.92 * min(max(loads[index], 0), 1))
                    }
                    .frame(width: isEfficiency ? 12 : 16, height: isEfficiency ? 12 : 16)
                    .padding(.trailing, index == efficiencyCount - 1 ? 6 : 0)
            }
        }
        .animation(.easeOut(duration: 0.5), value: loads)
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
        GeometryReader { proxy in
            let width = proxy.size.width
            HStack(spacing: 1.5) {
                ForEach(segments.indices, id: \.self) { index in
                    let segment = segments[index]
                    let segmentWidth = max(width * CGFloat(min(max(segment.fraction, 0), 1)) - 1.5, 0)
                    if segmentWidth > 0.5 {
                        segment.color
                            .frame(width: segmentWidth)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 6)
        .background(.fill.secondary)
        .clipShape(.capsule)
    }
}

struct RingGauge<Label: View>: View {
    let value: Double
    let color: Color
    var lineWidth: CGFloat = 4
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(.fill.secondary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            label()
        }
        .padding(lineWidth / 2)
    }
}

extension RingGauge where Label == EmptyView {
    init(value: Double, color: Color, lineWidth: CGFloat = 4) {
        self.init(value: value, color: color, lineWidth: lineWidth) { EmptyView() }
    }
}
