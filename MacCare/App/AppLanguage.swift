import AppKit
import Foundation

/// The interface language. `system` follows macOS; the others override it for Mac Care only.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case portuguese = "pt-BR"
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    /// Languages are named in themselves so people find theirs whatever the current language is.
    var displayName: String {
        switch self {
        case .system: String(localized: "Idioma do sistema")
        case .portuguese: "Português (Brasil)"
        case .english: "English"
        case .spanish: "Español"
        }
    }

    private static let appleLanguagesKey = "AppleLanguages"

    static var selected: AppLanguage {
        UserDefaults.standard.string(forKey: SettingsKey.language).flatMap(AppLanguage.init) ?? .system
    }

    /// The language the running app was launched with. A new choice only shows after a relaunch.
    private(set) static var atLaunch: AppLanguage = .system

    static func recordLaunchLanguage() {
        atLaunch = selected
    }

    /// Bundle resolves the app's localization from `AppleLanguages` once, when the app starts.
    static func select(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: SettingsKey.language)
        if language == .system {
            defaults.removeObject(forKey: appleLanguagesKey)
        } else {
            defaults.set([language.rawValue], forKey: appleLanguagesKey)
        }
    }

    /// Opens a fresh instance of the app and quits this one.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
