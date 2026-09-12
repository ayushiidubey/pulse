import Darwin

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
    }

    static func value<T: BitwiseCopyable>(_ name: String, default initial: T) -> T? {
        var value = initial
        var size = MemoryLayout<T>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
