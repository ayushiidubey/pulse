import AppKit
import Network
import Observation

struct AppTraffic: Identifiable {
    let owner: ProcessOwner
    var down: Double = 0
    var up: Double = 0

    var id: String { owner.key }
    var total: Double { down + up }
}

/// Samples the system once a second. CPU, memory and network counters run continuously because the
/// menu bar and the history graphs need them; everything else runs only while the panel is on screen.
@Observable
final class SystemMonitor {
    struct CPUState {
        var reading = CPUReading()
        var history = RollingSeries()
        var systemHistory = RollingSeries()
        var loadAverage: [Double] = [0, 0, 0]
        var thermalState: ProcessInfo.ThermalState = .nominal
    }

    enum Connection {
        case wifi, ethernet, cellular, other, offline
    }

    struct NetworkState {
        var down: Double = 0
        var up: Double = 0
        var downHistory = RollingSeries()
        var upHistory = RollingSeries()
        var connection: Connection = .offline
        var interfaceName: String?
        var localAddress: String?
        var publicAddress: String?
        var wifi: WiFiReading?
    }

    struct DiskState {
        var volume: DiskVolume?
        var readRate: Double = 0
        var writeRate: Double = 0
    }

    private(set) var cpu = CPUState()
    private(set) var memory: MemoryReading?
    private(set) var network = NetworkState()
    private(set) var disk = DiskState()
    private(set) var battery: BatteryReading?
    private(set) var topApps: [AppTraffic] = []
    /// False until the first per-app sample arrives, so the UI can say "measuring" rather than "idle".
    private(set) var hasTrafficSample = false
    private(set) var isPanelVisible = false
    /// Increments once per sample; charts use it to slide along by one step.
    private(set) var sampleTick = 0

    /// Live figures while a speed test runs; nil otherwise.
    private(set) var speedTestProgress: SpeedTestProgress?
    private(set) var speedTestResult: SpeedTestResult?
    private(set) var speedTestFailed = false

    let info = SystemInfo.current
    var efficiencyCoreCount: Int { cpuSampler.efficiencyCoreCount }

    @ObservationIgnored var onSample: (() -> Void)?
    @ObservationIgnored let owners = ProcessOwnerResolver()

    @ObservationIgnored private let cpuSampler = CPUSampler()
    @ObservationIgnored private let memorySampler = MemorySampler()
    @ObservationIgnored private let networkSampler = NetworkSampler()
    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private var downMeter = RateMeter()
    @ObservationIgnored private var upMeter = RateMeter()
    @ObservationIgnored private var readMeter = RateMeter()
    @ObservationIgnored private var writeMeter = RateMeter()
    @ObservationIgnored private var netTop: NetTopStream?
    @ObservationIgnored private var speedTest: SpeedTest?
    @ObservationIgnored private var samplingTask: Task<Void, Never>?
    @ObservationIgnored private var publicAddressTask: Task<Void, Never>?
    @ObservationIgnored private var publicAddressFetchedAt: Date?
    @ObservationIgnored private var tick = 0

    func start() {
        guard samplingTask == nil else { return }
        startPathMonitor()
        sample()
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1), tolerance: .milliseconds(100))
                self?.sample()
            }
        }
    }

    func setPanelVisible(_ visible: Bool) {
        guard visible != isPanelVisible else { return }
        isPanelVisible = visible

        if visible {
            sampleDetails(at: .now, includeSlowReadings: true)
            refreshPublicAddress()
            let stream = NetTopStream { entries in
                Task { @MainActor in self.applyTraffic(entries) }
            }
            stream.start()
            netTop = stream
        } else {
            netTop?.stop()
            netTop = nil
            readMeter.reset()
            writeMeter.reset()
            topApps = []
            hasTrafficSample = false
            owners.forgetProcesses()
        }
    }

    // MARK: Speed test

    /// Keeps running if the panel closes, so the result is waiting when it reopens.
    func startSpeedTest() {
        guard speedTest == nil, network.connection != .offline else { return }
        let test = SpeedTest()
        let id = ObjectIdentifier(test)
        speedTest = test
        speedTestFailed = false
        speedTestProgress = SpeedTestProgress()

        test.start(
            onProgress: { progress in
                Task { @MainActor in
                    guard self.isCurrentSpeedTest(id) else { return }
                    self.speedTestProgress = progress
                }
            },
            onFinish: { outcome in
                Task { @MainActor in
                    guard self.isCurrentSpeedTest(id) else { return }
                    self.speedTest = nil
                    self.speedTestProgress = nil
                    switch outcome {
                    case .finished(let result): self.speedTestResult = result
                    case .failed: self.speedTestFailed = true
                    }
                }
            }
        )
    }

    /// Stops a running test; the previous result, if any, stays on screen.
    func cancelSpeedTest() {
        speedTest?.cancel()
        speedTest = nil
        speedTestProgress = nil
    }

    private func isCurrentSpeedTest(_ id: ObjectIdentifier) -> Bool {
        speedTest.map { ObjectIdentifier($0) } == id
    }

    // MARK: Sampling

    private func sample() {
        let now = ContinuousClock.now
        tick &+= 1

        if let reading = cpuSampler.read() {
            var cpu = self.cpu
            cpu.reading = reading
            cpu.history.append(reading.total)
            cpu.systemHistory.append(reading.system)
            self.cpu = cpu
        }

        if let reading = memorySampler.read() {
            memory = reading
        }

        let counters = networkSampler.counters()
        var network = self.network
        network.down = downMeter.rate(counters.received, at: now) ?? 0
        network.up = upMeter.rate(counters.sent, at: now) ?? 0
        network.downHistory.append(network.down)
        network.upHistory.append(network.up)
        self.network = network
        sampleTick &+= 1

        if isPanelVisible {
            sampleDetails(at: now, includeSlowReadings: tick % 5 == 0)
        }
        onSample?()
    }

    private func sampleDetails(at now: ContinuousClock.Instant, includeSlowReadings: Bool) {
        cpu.loadAverage = CPUSampler.loadAverage()
        cpu.thermalState = ProcessInfo.processInfo.thermalState

        let io = DiskSampler.ioCounters()
        var disk = self.disk
        disk.readRate = readMeter.rate(io.read, at: now) ?? 0
        disk.writeRate = writeMeter.rate(io.written, at: now) ?? 0
        if includeSlowReadings || disk.volume == nil {
            disk.volume = DiskSampler.startupVolume() ?? disk.volume
        }
        self.disk = disk

        guard includeSlowReadings else { return }
        battery = BatterySampler.read()
        var network = self.network
        network.localAddress = network.interfaceName.flatMap { NetworkSampler.ipv4Address(interface: $0) }
        network.wifi = network.connection == .wifi ? NetworkSampler.wifi() : nil
        self.network = network
    }

    private func applyTraffic(_ entries: [NetTopEntry]) {
        guard isPanelVisible else { return }
        var byOwner: [String: AppTraffic] = [:]
        for entry in entries where entry.bytesIn > 0 || entry.bytesOut > 0 {
            let owner = owners.owner(pid: entry.pid, fallbackName: entry.name)
            byOwner[owner.key, default: AppTraffic(owner: owner)].down += Double(entry.bytesIn)
            byOwner[owner.key, default: AppTraffic(owner: owner)].up += Double(entry.bytesOut)
        }
        topApps = Array(byOwner.values.sorted { $0.total > $1.total }.prefix(3))
        hasTrafficSample = true
    }

    // MARK: Network path

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { path in
            let online = path.status == .satisfied
            // Skip VPN tunnels so the tile describes the physical link.
            let interface = path.availableInterfaces.first { $0.type != .other && $0.type != .loopback }
                ?? path.availableInterfaces.first
            let name = interface?.name
            let type = interface?.type
            MainActor.assumeIsolated {
                self.applyPath(online: online, interfaceName: name, type: type)
            }
        }
        pathMonitor.start(queue: .main)
    }

    private func applyPath(online: Bool, interfaceName: String?, type: NWInterface.InterfaceType?) {
        var network = self.network
        if online {
            network.connection = switch type {
            case .wifi?: .wifi
            case .wiredEthernet?: .ethernet
            case .cellular?: .cellular
            default: .other
            }
        } else {
            network.connection = .offline
            network.publicAddress = nil
        }
        network.interfaceName = online ? interfaceName : nil
        network.localAddress = network.interfaceName.flatMap { NetworkSampler.ipv4Address(interface: $0) }
        if network.connection != .wifi { network.wifi = nil }
        self.network = network

        networkSampler.resetInterfaces()
        publicAddressFetchedAt = nil
        if isPanelVisible {
            refreshPublicAddress()
            if network.connection == .wifi { self.network.wifi = NetworkSampler.wifi() }
        }
    }

    /// Looked up at most every ten minutes, and again whenever the network changes.
    private func refreshPublicAddress() {
        guard network.connection != .offline else { return }
        if let fetched = publicAddressFetchedAt, fetched.timeIntervalSinceNow > -600 { return }

        publicAddressTask?.cancel()
        publicAddressTask = Task {
            let request = URLRequest(url: URL(string: "https://api.ipify.org")!, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
            guard let result = try? await URLSession.shared.data(for: request),
                  (result.1 as? HTTPURLResponse)?.statusCode == 200,
                  let address = String(data: result.0, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !address.isEmpty, address.count <= 45, !Task.isCancelled else { return }
            network.publicAddress = address
            publicAddressFetchedAt = .now
        }
    }
}
