import Foundation

/// Launch flags for measuring what each animation costs, e.g. `open build/Pulse.app --args --no-ecg`.
enum DebugFlags {
    static let chartMotion = !CommandLine.arguments.contains("--no-chart-motion")
    static let ecgMotion = !CommandLine.arguments.contains("--no-ecg")
}
