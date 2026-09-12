import Darwin
import Foundation
import IOKit

struct SystemInfo {
    let model: String
    let chip: String
    let osVersion: String
    let bootDate: Date

    static let current = SystemInfo()

    private init() {
        model = Self.productName() ?? Sysctl.string("hw.model") ?? "Mac"
        chip = Sysctl.string("machdep.cpu.brand_string") ?? "Unknown chip"

        let version = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = "macOS \(version.majorVersion).\(version.minorVersion)" + (version.patchVersion > 0 ? ".\(version.patchVersion)" : "")

        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        bootDate = sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0
            ? Date(timeIntervalSince1970: TimeInterval(boot.tv_sec))
            : .now
    }

    /// Marketing name such as "MacBook Air (M2, 2022)", published in the device tree on Apple silicon.
    private static func productName() -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        guard entry != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(entry) }
        guard let data = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? Data else { return nil }
        let name = String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        return name.isEmpty ? nil : name
    }
}
