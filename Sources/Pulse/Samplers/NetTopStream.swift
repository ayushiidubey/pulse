import Foundation

nonisolated struct NetTopEntry: Sendable {
    let pid: pid_t
    let name: String
    let bytesIn: UInt64
    let bytesOut: UInt64
}

/// Streams per-process network usage (internet traffic only, not loopback) from `nettop`, once a second.
/// Runs only while the panel is open; create a fresh stream for each session.
nonisolated final class NetTopStream: @unchecked Sendable {
    private let onSample: @Sendable ([NetTopEntry]) -> Void
    private var terminal: TerminalProcess?

    // Parser state, touched only from the terminal's serial output handler.
    private var block: [NetTopEntry] = []
    private var blocksSeen = 0

    init(onSample: @escaping @Sendable ([NetTopEntry]) -> Void) {
        self.onSample = onSample
    }

    func start() {
        guard terminal == nil else { return }
        let terminal = TerminalProcess(
            executable: "/usr/bin/nettop",
            // -P per process, -d per-interval deltas, -x exact numbers, -t external skips loopback, -L 0 runs until stopped.
            arguments: ["-P", "-d", "-x", "-t", "external", "-s", "1", "-L", "0", "-J", "bytes_in,bytes_out"],
            onOutput: { [self] lines, endsAtLineBreak in
                handle(lines, endsAtLineBreak: endsAtLineBreak)
            }
        )
        terminal.start()
        self.terminal = terminal
    }

    func stop() {
        terminal?.stop()
        terminal = nil
    }

    private func handle(_ lines: [String], endsAtLineBreak: Bool) {
        lines.forEach(parse)
        // The first block is cumulative since boot; only later blocks are per-second deltas.
        if endsAtLineBreak, blocksSeen >= 2 {
            onSample(block)
        }
    }

    private func parse(_ line: String) {
        if line.hasPrefix(",") || line.hasPrefix("time,") {
            blocksSeen += 1
            block.removeAll(keepingCapacity: true)
            return
        }
        // "Google Chrome H.1994,2011025,643709,"
        let fields = line.split(separator: ",", omittingEmptySubsequences: false)
        guard fields.count >= 3,
              let bytesIn = UInt64(fields[1]),
              let bytesOut = UInt64(fields[2]),
              let dot = fields[0].lastIndex(of: "."),
              let pid = pid_t(fields[0][fields[0].index(after: dot)...]) else { return }
        block.append(NetTopEntry(pid: pid, name: String(fields[0][..<dot]), bytesIn: bytesIn, bytesOut: bytesOut))
    }
}
