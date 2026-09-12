import CoreWLAN
import Darwin
import Foundation

struct NetworkCounters {
    var received: UInt64 = 0
    var sent: UInt64 = 0
}

struct WiFiReading {
    var ssid: String?
    var rssi: Int
    var transmitRate: Double
    var band: String?

    /// 0 at -90 dBm, 1 at -50 dBm and above.
    var signal: Double { min(max(Double(rssi + 90) / 40, 0), 1) }
}

final class NetworkSampler {
    private var isPhysicalByIndex: [UInt16: Bool] = [:]

    /// Total bytes across physical interfaces (Wi-Fi, Ethernet, cellular), using 64-bit counters.
    func counters() -> NetworkCounters {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0, length > 0 else { return NetworkCounters() }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, u_int(mib.count), &buffer, &length, nil, 0) == 0 else { return NetworkCounters() }

        var totals = NetworkCounters()
        buffer.withUnsafeBytes { raw in
            var offset = 0
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if isPhysical(message.ifm_index) {
                        totals.received += message.ifm_data.ifi_ibytes
                        totals.sent += message.ifm_data.ifi_obytes
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return totals
    }

    /// Interface indices can be reused when interfaces come and go.
    func resetInterfaces() {
        isPhysicalByIndex.removeAll()
    }

    private func isPhysical(_ index: UInt16) -> Bool {
        if let known = isPhysicalByIndex[index] { return known }
        var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        var physical = false
        if if_indextoname(UInt32(index), &name) != nil {
            let interface = name.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            physical = interface.hasPrefix("en") || interface.hasPrefix("pdp_ip")
        }
        isPhysicalByIndex[index] = physical
        return physical
    }

    static func ipv4Address(interface: String) -> String? {
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return nil }
        defer { freeifaddrs(addresses) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  String(cString: entry.ifa_name) == interface else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                return host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            }
        }
        return nil
    }

    static func wifi() -> WiFiReading? {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else { return nil }
        let band: String? = switch interface.wlanChannel()?.channelBand {
        case .band2GHz: "2.4 GHz"
        case .band5GHz: "5 GHz"
        case .band6GHz: "6 GHz"
        default: nil
        }
        // The SSID stays nil unless the app has Location access, which Pulse deliberately doesn't ask for.
        return WiFiReading(ssid: interface.ssid(), rssi: interface.rssiValue(), transmitRate: interface.transmitRate(), band: band)
    }
}
