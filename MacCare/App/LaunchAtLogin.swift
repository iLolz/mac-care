import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registered, but switched off by the user in System Settings › Login Items.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status != .notRegistered else { return }
            try service.unregister()
        }
    }

    /// On by default: registers once on the first launch, then follows the user's choice.
    static func configureOnFirstLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: SettingsKey.didConfigureLaunchAtLogin) else { return }
        defaults.set(true, forKey: SettingsKey.didConfigureLaunchAtLogin)
        try? setEnabled(true)
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
