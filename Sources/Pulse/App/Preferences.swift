import Foundation
import Observation
import ServiceManagement

enum MenuBarMode: String, CaseIterable, Identifiable {
    case cpu, memory, network

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "Memory"
        case .network: "Network"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .memory: "memorychip"
        case .network: "arrow.up.arrow.down"
        }
    }
}

@Observable
final class Preferences {
    private(set) var menuBarMode: MenuBarMode
    private(set) var launchesAtLogin: Bool

    @ObservationIgnored var onMenuBarModeChange: (() -> Void)?

    init() {
        menuBarMode = UserDefaults.standard.string(forKey: Keys.menuBarMode).flatMap { MenuBarMode(rawValue: $0) } ?? .cpu
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setMenuBarMode(_ mode: MenuBarMode) {
        guard mode != menuBarMode else { return }
        menuBarMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: Keys.menuBarMode)
        onMenuBarModeChange?()
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Pulse: could not change launch at login: \(error.localizedDescription)")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    private enum Keys {
        static let menuBarMode = "menuBarMode"
    }
}
