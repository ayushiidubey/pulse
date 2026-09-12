import Foundation
import IOKit
import IOKit.ps

struct BatteryReading {
    enum State {
        case charging, charged, pluggedIn, discharging
    }

    var level: Double
    var state: State
    var minutesRemaining: Int?
    var health: Double?
    var cycleCount: Int?
    var temperature: Double?
    /// Positive while charging, negative while draining.
    var watts: Double?
}

enum BatterySampler {
    /// Nil on Macs without an internal battery.
    static func read() -> BatteryReading? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description["Type"] as? String == "InternalBattery" else { continue }

            let current = description["Current Capacity"] as? Int ?? 0
            let capacity = max(description["Max Capacity"] as? Int ?? 100, 1)
            let onAC = description["Power Source State"] as? String == "AC Power"
            let charging = description["Is Charging"] as? Bool ?? false
            let charged = description["Is Charged"] as? Bool ?? false

            let state: BatteryReading.State = charging ? .charging : onAC ? (charged ? .charged : .pluggedIn) : .discharging
            let minutes = description[charging ? "Time to Full Charge" : "Time to Empty"] as? Int

            var reading = BatteryReading(
                level: Double(current) / Double(capacity),
                state: state,
                minutesRemaining: (charging || !onAC) && (minutes ?? 0) > 0 ? minutes : nil
            )
            addSmartBatteryDetails(to: &reading)
            return reading
        }
        return nil
    }

    private static func addSmartBatteryDetails(to reading: inout BatteryReading) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        func number(_ key: String) -> NSNumber? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber
        }

        if let design = number("DesignCapacity")?.doubleValue, design > 0,
           let full = (number("NominalChargeCapacity") ?? number("AppleRawMaxCapacity"))?.doubleValue {
            reading.health = min(full / design, 1)
        }
        reading.cycleCount = number("CycleCount")?.intValue
        if let centidegrees = number("Temperature")?.doubleValue {
            reading.temperature = centidegrees / 100
        }
        if let millivolts = number("Voltage")?.doubleValue, let milliamps = number("InstantAmperage")?.int64Value {
            reading.watts = millivolts * Double(milliamps) / 1_000_000
        }
    }
}
