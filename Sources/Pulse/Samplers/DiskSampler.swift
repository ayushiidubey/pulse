import Foundation
import IOKit

struct DiskVolume {
    var name: String
    var total: Double
    var available: Double

    var usedFraction: Double { total > 0 ? (total - available) / total : 0 }
}

enum DiskSampler {
    /// The startup volume. "Available" includes purgeable space, as Finder reports it.
    static func startupVolume() -> DiskVolume? {
        let keys: Set<URLResourceKey> = [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: keys),
              let total = values.volumeTotalCapacity else { return nil }
        return DiskVolume(
            name: values.volumeName ?? "Macintosh HD",
            total: Double(total),
            available: Double(values.volumeAvailableCapacityForImportantUsage ?? 0)
        )
    }

    /// Cumulative bytes read and written across all block storage drivers.
    static func ioCounters() -> (read: UInt64, written: UInt64) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOBlockStorageDriver"), &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var read: UInt64 = 0, written: UInt64 = 0
        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] {
                read += (stats["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                written += (stats["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        return (read, written)
    }
}
