import Darwin
import Foundation

enum MemoryPressure {
    case normal, warning, critical
}

/// Memory broken down the way Activity Monitor reports it.
struct MemoryReading {
    var total: UInt64
    var app: UInt64
    var wired: UInt64
    var compressed: UInt64
    var cached: UInt64
    var swapUsed: UInt64
    var pressure: MemoryPressure

    var used: UInt64 { app + wired + compressed }
    var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
}

final class MemorySampler {
    private let host = mach_host_self()
    private let total = ProcessInfo.processInfo.physicalMemory
    private let pageSize: UInt64

    init() {
        var size: vm_size_t = 0
        host_page_size(host, &size)
        pageSize = UInt64(size)
    }

    func read() -> MemoryReading? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let host = self.host
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let page = pageSize
        let anonymous = UInt64(stats.internal_page_count) * page
        let purgeable = UInt64(stats.purgeable_count) * page
        let fileBacked = UInt64(stats.external_page_count) * page

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) != 0 {
            swap = xsw_usage()
        }

        let level = Sysctl.value("kern.memorystatus_vm_pressure_level", default: Int32(1)) ?? 1
        return MemoryReading(
            total: total,
            app: anonymous > purgeable ? anonymous - purgeable : 0,
            wired: UInt64(stats.wire_count) * page,
            compressed: UInt64(stats.compressor_page_count) * page,
            cached: fileBacked + purgeable,
            swapUsed: swap.xsu_used,
            pressure: level >= 4 ? .critical : level >= 2 ? .warning : .normal
        )
    }
}
