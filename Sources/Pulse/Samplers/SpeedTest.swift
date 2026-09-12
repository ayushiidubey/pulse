import Foundation

nonisolated struct SpeedTestProgress: Sendable {
    var downloadMbps: Double = 0
    var uploadMbps: Double = 0
}

nonisolated struct SpeedTestResult: Sendable {
    let downloadMbps: Double
    let uploadMbps: Double
    let responsivenessRPM: Double?
    /// Apple's own rating ("Low", "Medium" or "High") from networkQuality's summary.
    let responsivenessRating: String?
    let idleLatencyMilliseconds: Double?
    let date: Date
}

nonisolated enum SpeedTestOutcome: Sendable {
    case finished(SpeedTestResult)
    case failed
}

/// One run of Apple's `networkQuality`, which measures download and upload capacity in parallel against
/// Apple's CDN. Live figures come from its terminal output; the final result comes from its JSON report.
nonisolated final class SpeedTest: @unchecked Sendable {
    private let reportURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pulse-speed-test-\(UUID().uuidString).json")
    private let lock = NSLock()
    private var terminal: TerminalProcess?

    // Touched only from the terminal's serial output and finish handlers.
    private var rating: String?

    func start(onProgress: @escaping @Sendable (SpeedTestProgress) -> Void, onFinish: @escaping @Sendable (SpeedTestOutcome) -> Void) {
        let terminal = TerminalProcess(
            executable: "/usr/bin/networkQuality",
            // The report path must be attached to -c; as a separate argument it is rejected. -M caps the run time.
            arguments: ["-c\(reportURL.path)", "-M", "25"],
            onOutput: { [self] lines, _ in
                for line in lines {
                    if let progress = Self.progress(from: line) {
                        onProgress(progress)
                    } else if let rating = Self.rating(from: line) {
                        self.rating = rating
                    }
                }
            },
            onFinish: { [self] in
                let outcome = readReport()
                releaseTerminal()
                onFinish(outcome)
            }
        )
        lock.withLock { self.terminal = terminal }
        if !terminal.start() {
            releaseTerminal()
            onFinish(.failed)
        }
    }

    func cancel() {
        let terminal = lock.withLock { () -> TerminalProcess? in
            defer { self.terminal = nil }
            return self.terminal
        }
        terminal?.stop()
        try? FileManager.default.removeItem(at: reportURL)
    }

    private func releaseTerminal() {
        lock.withLock { terminal = nil }
    }

    private func readReport() -> SpeedTestOutcome {
        defer { try? FileManager.default.removeItem(at: reportURL) }
        guard let data = try? Data(contentsOf: reportURL),
              let report = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let download = (report["dl_throughput"] as? NSNumber)?.doubleValue,
              let upload = (report["ul_throughput"] as? NSNumber)?.doubleValue,
              download > 0 || upload > 0 else { return .failed }

        return .finished(SpeedTestResult(
            downloadMbps: download / 1_000_000,
            uploadMbps: upload / 1_000_000,
            responsivenessRPM: (report["responsiveness"] as? NSNumber)?.doubleValue,
            responsivenessRating: rating,
            idleLatencyMilliseconds: (report["base_rtt"] as? NSNumber)?.doubleValue,
            date: .now
        ))
    }

    /// "Downlink: 112.326 Mbps, 206 RPM - Uplink: 102.134 Mbps, 206 RPM"
    private static func progress(from line: String) -> SpeedTestProgress? {
        guard line.hasPrefix("Downlink:"), line.contains("Uplink:") else { return nil }
        let numbers = line.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard numbers.count >= 3 else { return nil }
        return SpeedTestProgress(downloadMbps: numbers[0], uploadMbps: numbers[2])
    }

    /// "Responsiveness: Medium (294.282 milliseconds | 203 RPM)"
    private static func rating(from line: String) -> String? {
        guard line.hasPrefix("Responsiveness:") else { return nil }
        return line.dropFirst("Responsiveness:".count).split(separator: " ").first.map(String.init)
    }
}
