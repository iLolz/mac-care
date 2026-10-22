import Foundation

enum SettingsKey {
    static let showInMenuBar = "showInMenuBar"
    static let didConfigureLaunchAtLogin = "didConfigureLaunchAtLogin"
}

enum AppSettings {
    static let showInMenuBarDefault = true
    /// Free space below this fraction of the disk is shown as low. Becomes configurable with alerts.
    static let lowSpaceFraction = 0.10

    static var showInMenuBar: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.showInMenuBar) as? Bool ?? showInMenuBarDefault
    }
}

enum WindowID {
    static let main = "main"
}
