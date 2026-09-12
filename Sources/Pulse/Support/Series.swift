import Foundation

/// A fixed-length window of the most recent samples, oldest first.
struct RollingSeries {
    let capacity: Int
    private(set) var values: [Double] = []

    init(capacity: Int = 60) {
        self.capacity = capacity
        values.reserveCapacity(capacity)
    }

    mutating func append(_ value: Double) {
        if values.count == capacity { values.removeFirst() }
        values.append(value)
    }

    var peak: Double { values.max() ?? 0 }
}

/// Turns a monotonically increasing counter into a per-second rate.
struct RateMeter {
    private var last: (value: UInt64, time: ContinuousClock.Instant)?

    /// Nil on the first reading and whenever the counter goes backwards (an interface or disk went away).
    mutating func rate(_ value: UInt64, at time: ContinuousClock.Instant) -> Double? {
        defer { last = (value, time) }
        guard let last, value >= last.value else { return nil }
        let elapsed = (time - last.time).components
        let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        guard seconds > 0.05 else { return nil }
        return Double(value - last.value) / seconds
    }

    mutating func reset() {
        last = nil
    }
}
