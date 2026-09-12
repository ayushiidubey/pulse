import Darwin
import Foundation

struct CPUReading {
    var user: Double = 0
    var system: Double = 0
    /// Busy fraction per logical core, in kernel order (efficiency cores first on Apple silicon).
    var cores: [Double] = []

    var total: Double { user + system }
}

final class CPUSampler {
    let efficiencyCoreCount = Sysctl.value("hw.perflevel1.logicalcpu", default: Int32(0)).map { Int($0) } ?? 0

    private let host = mach_host_self()
    private var previous: [UInt32] = []

    /// Usage since the previous call; nil on the first call.
    func read() -> CPUReading? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return nil }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }

        let current = (0..<Int(infoCount)).map { UInt32(bitPattern: info[$0]) }
        let previous = self.previous
        self.previous = current
        guard previous.count == current.count else { return nil }

        let states = Int(CPU_STATE_MAX)
        var user: UInt64 = 0, system: UInt64 = 0, total: UInt64 = 0
        var cores = [Double]()
        cores.reserveCapacity(Int(cpuCount))

        for core in 0..<Int(cpuCount) {
            let base = core * states
            func ticks(_ state: Int32) -> UInt64 {
                UInt64(current[base + Int(state)] &- previous[base + Int(state)])
            }
            let coreUser = ticks(CPU_STATE_USER) + ticks(CPU_STATE_NICE)
            let coreSystem = ticks(CPU_STATE_SYSTEM)
            let coreTotal = coreUser + coreSystem + ticks(CPU_STATE_IDLE)
            user += coreUser
            system += coreSystem
            total += coreTotal
            cores.append(coreTotal > 0 ? Double(coreUser + coreSystem) / Double(coreTotal) : 0)
        }

        guard total > 0 else { return nil }
        return CPUReading(user: Double(user) / Double(total), system: Double(system) / Double(total), cores: cores)
    }

    static func loadAverage() -> [Double] {
        var loads = [Double](repeating: 0, count: 3)
        return getloadavg(&loads, 3) == 3 ? loads : [0, 0, 0]
    }
}
