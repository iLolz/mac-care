import Foundation

public enum CategoryID: String, CaseIterable, Codable, Sendable {
    case userCaches
    case logs
    case trash
    case oldDownloads
    case xcodeDerivedData
    case xcodeDeviceSupport
    case simulatorCaches
    case developerCaches
    case nodeModules
}

/// Describes where a category looks and which items it considers removable.
public struct ScanRule: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Every direct child of `root` is a removable item.
        case contents
        /// Direct children of `root` not modified or created in the last `days` days.
        case olderThan(days: Int)
        /// Directories called `name` found under `root`, up to `maxDepth` levels deep.
        case namedDirectories(name: String, maxDepth: Int)
    }

    public let root: URL
    public let kind: Kind

    public init(root: URL, kind: Kind) {
        self.root = root
        self.kind = kind
    }
}

public struct CleanupCategory: Identifiable, Sendable {
    public let id: CategoryID
    public let title: String
    public let summary: String
    /// SF Symbol name.
    public let symbol: String
    public let rules: [ScanRule]

    public init(id: CategoryID, title: String, summary: String, symbol: String, rules: [ScanRule]) {
        self.id = id
        self.title = title
        self.summary = summary
        self.symbol = symbol
        self.rules = rules
    }
}

extension CleanupCategory {
    /// Folders under the home directory where projects (and their node_modules) usually live.
    public static let defaultProjectRoots = [
        "Developer", "Projects", "Projetos", "Code", "dev", "workspace", "Documents/GitHub",
    ]

    public static func catalog(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        downloadsAgeDays: Int = 30,
        projectRoots: [String] = defaultProjectRoots
    ) -> [CleanupCategory] {
        func path(_ relative: String) -> URL {
            home.appendingPathComponent(relative, isDirectory: true)
        }

        return [
            CleanupCategory(
                id: .userCaches,
                title: "Caches de apps",
                summary: "Arquivos temporários que os apps recriam quando precisam.",
                symbol: "internaldrive",
                rules: [ScanRule(root: path("Library/Caches"), kind: .contents)]
            ),
            CleanupCategory(
                id: .logs,
                title: "Logs",
                summary: "Registros de diagnóstico de apps e do sistema do usuário.",
                symbol: "doc.text",
                rules: [ScanRule(root: path("Library/Logs"), kind: .contents)]
            ),
            CleanupCategory(
                id: .trash,
                title: "Lixeira",
                summary: "Itens que já estão na Lixeira.",
                symbol: "trash",
                rules: [ScanRule(root: path(".Trash"), kind: .contents)]
            ),
            CleanupCategory(
                id: .oldDownloads,
                title: "Downloads antigos",
                summary: "Arquivos em Downloads com mais de \(downloadsAgeDays) dias.",
                symbol: "arrow.down.circle",
                rules: [ScanRule(root: path("Downloads"), kind: .olderThan(days: downloadsAgeDays))]
            ),
            CleanupCategory(
                id: .xcodeDerivedData,
                title: "Xcode DerivedData",
                summary: "Builds intermediários do Xcode, recriados no próximo build.",
                symbol: "hammer",
                rules: [ScanRule(root: path("Library/Developer/Xcode/DerivedData"), kind: .contents)]
            ),
            CleanupCategory(
                id: .xcodeDeviceSupport,
                title: "Suporte a dispositivos do Xcode",
                summary: "Símbolos de versões de iOS/watchOS de aparelhos já conectados.",
                symbol: "iphone",
                rules: [
                    ScanRule(root: path("Library/Developer/Xcode/iOS DeviceSupport"), kind: .contents),
                    ScanRule(root: path("Library/Developer/Xcode/watchOS DeviceSupport"), kind: .contents),
                ]
            ),
            CleanupCategory(
                id: .simulatorCaches,
                title: "Caches do Simulador",
                summary: "Caches do CoreSimulator.",
                symbol: "ipad.and.iphone",
                rules: [ScanRule(root: path("Library/Developer/CoreSimulator/Caches"), kind: .contents)]
            ),
            CleanupCategory(
                id: .developerCaches,
                title: "Caches de ferramentas de dev",
                summary: "Caches do npm e do Gradle, baixados de novo quando necessário.",
                symbol: "shippingbox",
                rules: [
                    ScanRule(root: path(".npm/_cacache"), kind: .contents),
                    ScanRule(root: path(".gradle/caches"), kind: .contents),
                ]
            ),
            CleanupCategory(
                id: .nodeModules,
                title: "node_modules",
                summary: "Dependências de projetos JavaScript, reinstaláveis com npm install.",
                symbol: "folder.badge.gearshape",
                rules: projectRoots.map {
                    ScanRule(root: path($0), kind: .namedDirectories(name: "node_modules", maxDepth: 4))
                }
            ),
        ]
    }
}
