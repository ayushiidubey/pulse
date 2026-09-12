import Darwin
import Foundation

/// Runs a command-line tool on a pseudo-terminal and delivers its output line by line.
/// Tools such as `nettop` and `networkQuality` block-buffer into a pipe, and only flush each update
/// when they believe they are writing to a terminal.
nonisolated final class TerminalProcess: @unchecked Sendable {
    /// The complete lines from one read, and whether that read ended exactly at a line break.
    typealias OutputHandler = @Sendable (_ lines: [String], _ endsAtLineBreak: Bool) -> Void

    /// Runs the tool with a lifeline pipe from Pulse on the shell's stdin. However Pulse exits, crashes
    /// included, the kernel closes that pipe and the watcher kills the tool. Without it, a tool writing to a
    /// terminal nobody reads keeps running forever, because the terminal never becomes its controlling tty
    /// and so never delivers a hangup.
    private static let supervisor = """
        exec 3<&0 </dev/null
        "$@" 3<&- &
        tool=$!
        exec >/dev/null 2>&1
        { read line <&3; kill "$tool" 2>/dev/null; } &
        watcher=$!
        exec 3<&-
        wait "$tool"
        kill "$watcher" 2>/dev/null
        """

    private let executable: String
    private let arguments: [String]
    private let onOutput: OutputHandler
    private let onFinish: (@Sendable () -> Void)?
    private let queue = DispatchQueue(label: "pulse.terminal-process")
    private let lock = NSLock()
    private var process: Process?
    private var lifeline: Pipe?
    private var source: (any DispatchSourceRead)?

    // Touched only on `queue`.
    private var pending: [UInt8] = []

    /// `onFinish` runs once the tool has exited and all of its output has been delivered,
    /// but not after `stop()`.
    init(executable: String, arguments: [String], onOutput: @escaping OutputHandler, onFinish: (@Sendable () -> Void)? = nil) {
        self.executable = executable
        self.arguments = arguments
        self.onOutput = onOutput
        self.onFinish = onFinish
    }

    /// Returns false if the tool could not be launched.
    @discardableResult
    func start() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard process == nil else { return true }

        var primary: Int32 = -1, replica: Int32 = -1
        var size = winsize(ws_row: 500, ws_col: 1024, ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&primary, &replica, nil, nil, &size) == 0 else { return false }

        let terminal = FileHandle(fileDescriptor: replica, closeOnDealloc: true)
        let lifeline = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", Self.supervisor, "pulse-helper", executable] + arguments
        process.standardInput = lifeline
        process.standardOutput = terminal
        process.standardError = FileHandle.nullDevice

        // A dispatch source rather than FileHandle: reading a pty fails with EIO once the tool exits,
        // and FileHandle turns that into an Objective-C exception.
        let source = DispatchSource.makeReadSource(fileDescriptor: primary, queue: queue)
        source.setEventHandler { [self] in
            var buffer = [UInt8](repeating: 0, count: 16_384)
            let count = read(primary, &buffer, buffer.count)
            if count > 0 {
                consume(buffer[0..<count])
                return
            }
            let wasStopped = release()
            if !wasStopped { onFinish?() }
        }
        source.setCancelHandler {
            close(primary)
        }

        do {
            try process.run()
        } catch {
            try? terminal.close()
            close(primary)
            return false
        }
        // The tool holds its own copy; closing ours lets the read side see end-of-file when it exits.
        try? terminal.close()
        self.process = process
        self.lifeline = lifeline
        self.source = source
        source.resume()
        return true
    }

    func stop() {
        release()
    }

    /// Cancels reading and cuts the lifeline, which makes the supervisor kill the tool if it is still running.
    /// Returns true if the process had already been released.
    @discardableResult
    private func release() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let source else { return true }
        source.cancel()
        self.source = nil
        try? lifeline?.fileHandleForWriting.close()
        lifeline = nil
        process = nil
        return false
    }

    private func consume(_ bytes: ArraySlice<UInt8>) {
        pending.append(contentsOf: bytes)
        var lines: [String] = []
        var lineStart = 0
        // Progress displays redraw with a bare carriage return, so treat it as a line break too.
        for index in pending.indices where pending[index] == 0x0A || pending[index] == 0x0D {
            if index > lineStart {
                let line = Self.plainText(pending[lineStart..<index])
                if !line.isEmpty { lines.append(line) }
            }
            lineStart = index + 1
        }
        pending.removeFirst(lineStart)
        onOutput(lines, pending.isEmpty)
    }

    /// Strips terminal control sequences such as "ESC[2K" (erase line) and other control characters.
    private static func plainText(_ bytes: ArraySlice<UInt8>) -> String {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var iterator = bytes.makeIterator()
        while let byte = iterator.next() {
            if byte == 0x1B {
                if iterator.next() == UInt8(ascii: "[") {
                    while let next = iterator.next(), !(0x40...0x7E).contains(next) {}
                }
                continue
            }
            if byte >= 0x20 || byte == 0x09 {
                output.append(byte)
            }
        }
        return String(decoding: output, as: UTF8.self)
    }
}
