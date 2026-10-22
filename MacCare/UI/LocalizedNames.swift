import CleanerKit
import Foundation

// CleanerKit names categories and failures in Portuguese; these give the UI the user's language.

extension CleanupCategory {
    var localizedTitle: String {
        switch id {
        case .userCaches: String(localized: "Caches de apps")
        case .logs: String(localized: "Logs")
        case .trash: String(localized: "Lixeira")
        case .oldDownloads: String(localized: "Downloads antigos")
        case .xcodeDerivedData: String(localized: "Xcode DerivedData")
        case .xcodeDeviceSupport: String(localized: "Suporte a dispositivos do Xcode")
        case .simulatorCaches: String(localized: "Caches do Simulador")
        case .developerCaches: String(localized: "Caches de ferramentas de dev")
        case .nodeModules: String(localized: "node_modules")
        }
    }

    var localizedSummary: String {
        switch id {
        case .userCaches: String(localized: "Arquivos temporários que os apps recriam quando precisam.")
        case .logs: String(localized: "Registros de diagnóstico de apps e do sistema do usuário.")
        case .trash: String(localized: "Itens que já estão na Lixeira.")
        case .oldDownloads: String(localized: "Arquivos em Downloads com mais de \(downloadsAgeDays) dias.")
        case .xcodeDerivedData: String(localized: "Builds intermediários do Xcode, recriados no próximo build.")
        case .xcodeDeviceSupport: String(localized: "Símbolos de versões de iOS/watchOS de aparelhos já conectados.")
        case .simulatorCaches: String(localized: "Caches do CoreSimulator.")
        case .developerCaches: String(localized: "Caches do npm e do Gradle, baixados de novo quando necessário.")
        case .nodeModules: String(localized: "Dependências de projetos JavaScript, reinstaláveis com npm install.")
        }
    }

    private var downloadsAgeDays: Int {
        for rule in rules {
            if case .olderThan(let days) = rule.kind { return days }
        }
        return 0
    }
}

extension CleanupFailure {
    /// The reasons CleanerKit gives are fixed phrases, translated in the string catalog.
    /// Anything else is a system error description, already in the user's language.
    var localizedReason: String {
        Bundle.main.localizedString(forKey: reason, value: reason, table: nil)
    }
}
