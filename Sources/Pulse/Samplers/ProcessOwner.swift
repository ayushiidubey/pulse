import AppKit
import Darwin

/// The app (or command-line tool) a process belongs to, so helpers roll up under their parent app.
struct ProcessOwner {
    let key: String
    let name: String
    let appPath: String?
}

final class ProcessOwnerResolver {
    private var ownersByPID: [pid_t: ProcessOwner] = [:]
    private var iconsByPath: [String: NSImage] = [:]

    func owner(pid: pid_t, fallbackName: String) -> ProcessOwner {
        if let cached = ownersByPID[pid] { return cached }
        let owner = resolve(pid: pid, fallbackName: fallbackName)
        ownersByPID[pid] = owner
        return owner
    }

    func icon(for owner: ProcessOwner) -> NSImage? {
        guard let path = owner.appPath else { return nil }
        if let icon = iconsByPath[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        iconsByPath[path] = icon
        return icon
    }

    /// PIDs get reused, so forget them between panel sessions.
    func forgetProcesses() {
        ownersByPID.removeAll()
    }

    private func resolve(pid: pid_t, fallbackName: String) -> ProcessOwner {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
            return ProcessOwner(key: fallbackName, name: fallbackName, appPath: nil)
        }
        let path = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }

        // The outermost bundle wins: ".../Google Chrome.app/.../Google Chrome Helper.app/..." is Chrome.
        if let range = path.range(of: ".app/") {
            let appPath = String(path[..<range.lowerBound]) + ".app"
            let displayName = FileManager.default.displayName(atPath: appPath)
            let name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
            return ProcessOwner(key: appPath, name: name, appPath: appPath)
        }

        // Tools installed as ".../claude/versions/2.1.267" read better by their package name.
        let skipped: Set<String> = ["bin", "sbin", "libexec", "versions", "Current", "MacOS"]
        let name = path.split(separator: "/").reversed()
            .first { !skipped.contains(String($0)) && !($0.first?.isNumber ?? true) }
            .map(String.init) ?? fallbackName
        return ProcessOwner(key: path, name: name, appPath: nil)
    }
}
