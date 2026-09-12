import Darwin
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
    private let queue = DispatchQueue(label: "pulse.nettop")
    private let lock = NSLock()
    private var process: Process?
    private var source: (any DispatchSourceRead)?

    // Parser state, touched only on `queue`.
    private var pending: [UInt8] = []
    private var block: [NetTopEntry] = []
    private var blocksSeen = 0

    init(onSample: @escaping @Sendable ([NetTopEntry]) -> Void) {
        self.onSample = onSample
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard process == nil else { return }

        // nettop block-buffers into a pipe and only flushes each sample when writing to a terminal.
        var primary: Int32 = -1, replica: Int32 = -1
        var size = winsize(ws_row: 500, ws_col: 1024, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&primary, &replica, nil, nil, &size) == 0 else { return }

        let terminal = FileHandle(fileDescriptor: replica, closeOnDealloc: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        // -P per process, -d per-interval deltas, -x exact numbers, -t external skips loopback, -L 0 runs until stopped.
        process.arguments = ["-P", "-d", "-x", "-t", "external", "-s", "1", "-L", "0", "-J", "bytes_in,bytes_out"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = terminal
        process.standardError = FileHandle.nullDevice

        // Read with a dispatch source rather than FileHandle: a pty read fails with EIO once nettop exits,
        // and FileHandle turns that into an Objective-C exception.
        let source = DispatchSource.makeReadSource(fileDescriptor: primary, queue: queue)
        source.setEventHandler { [self] in
            var buffer = [UInt8](repeating: 0, count: 16_384)
            let count = read(primary, &buffer, buffer.count)
            if count > 0 {
                consume(buffer[0..<count])
            } else {
                self.source?.cancel()
            }
        }
        source.setCancelHandler {
            close(primary)
        }

        do {
            try process.run()
            try? terminal.close()
            source.resume()
            self.process = process
            self.source = source
        } catch {
            try? terminal.close()
            close(primary)
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        source?.cancel()
        source = nil
        if let process, process.isRunning {
            process.terminate()
        }
        process = nil
    }

    private func consume(_ bytes: ArraySlice<UInt8>) {
        pending.append(contentsOf: bytes)
        var lineStart = 0
        for index in pending.indices where pending[index] == UInt8(ascii: "\n") {
            var lineEnd = index
            if lineEnd > lineStart, pending[lineEnd - 1] == UInt8(ascii: "\r") { lineEnd -= 1 }
            parse(String(decoding: pending[lineStart..<lineEnd], as: UTF8.self))
            lineStart = index + 1
        }
        pending.removeFirst(lineStart)

        // The first block is cumulative since boot; only later blocks are per-second deltas.
        if pending.isEmpty, blocksSeen >= 2 {
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
