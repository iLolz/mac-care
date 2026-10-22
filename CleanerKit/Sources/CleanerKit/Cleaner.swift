import Foundation

/// The items of one category that the user confirmed for cleanup.
public struct CleanupPlanEntry: Sendable, Equatable {
    public let category: CategoryID
    public let title: String
    public let items: [ScanItem]

    public init(category: CategoryID, title: String, items: [ScanItem]) {
        self.category = category
        self.title = title
        self.items = items
    }
}

public enum CleanupAction: Sendable {
    case moveToTrash
    /// Permanent removal. Only used for items that are already in the Trash.
    case delete

    public static func `for`(_ category: CategoryID) -> CleanupAction {
        category == .trash ? .delete : .moveToTrash
    }
}

public struct CleanupFailure: Sendable, Hashable {
    public let category: CategoryID
    public let item: ScanItem
    public let reason: String

    public init(category: CategoryID, item: ScanItem, reason: String) {
        self.category = category
        self.item = item
        self.reason = reason
    }
}

public struct CleanupSummary: Sendable, Equatable {
    public internal(set) var trashedBytes: Int64 = 0
    public internal(set) var trashedCount = 0
    public internal(set) var deletedBytes: Int64 = 0
    public internal(set) var deletedCount = 0
    public internal(set) var failures: [CleanupFailure] = []
    public internal(set) var wasCancelled = false

    public init() {}

    public var removedBytes: Int64 { trashedBytes + deletedBytes }
}

public enum CleanupEvent: Sendable, Equatable {
    case categoryStarted(CategoryID)
    /// `index` (from 0) and `total` count items across the whole plan.
    case itemStarted(CategoryID, item: ScanItem, index: Int, total: Int)
    case itemFinished(CategoryID, item: ScanItem)
    case itemFailed(CategoryID, item: ScanItem, reason: String)
    case categoryFinished(CategoryID, removedBytes: Int64, failures: Int)
    case finished(CleanupSummary)
}

/// Performs the actual file operation, injectable so tests never touch the disk.
public protocol FileRemoving: Sendable {
    func perform(_ action: CleanupAction, on url: URL) throws
}

public struct SystemFileRemover: FileRemoving {
    public init() {}

    public func perform(_ action: CleanupAction, on url: URL) throws {
        switch action {
        case .moveToTrash:
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        case .delete:
            try FileManager.default.removeItem(at: url)
        }
    }
}

/// Decides whether an item may be removed: it must sit strictly inside one of its category's
/// roots, inside the home folder, and never be the home folder or a root itself.
public struct CleanupSafety: Sendable {
    private let home: [String]
    private let roots: [CategoryID: [[String]]]

    public init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        categories: [CleanupCategory]
    ) {
        self.home = home.resolvingSymlinksInPath().pathComponents
        var roots: [CategoryID: [[String]]] = [:]
        for category in categories {
            roots[category.id, default: []] += category.rules.map {
                $0.root.resolvingSymlinksInPath().pathComponents
            }
        }
        self.roots = roots
    }

    /// Why `url` must not be removed as part of `category`, or nil when it is allowed.
    public func refusal(for url: URL, in category: CategoryID) -> String? {
        guard url.isFileURL else { return "Fora das pastas permitidas" }
        let standardized = url.standardizedFileURL
        let name = standardized.lastPathComponent
        guard !name.isEmpty, name != "/", name != ".", name != ".." else {
            return "Fora das pastas permitidas"
        }

        // Resolve the parent only: a symlinked item is removed as a link, never followed.
        let path = standardized.deletingLastPathComponent().resolvingSymlinksInPath()
            .appendingPathComponent(name).pathComponents

        guard Self.isStrictlyInside(path, home) else { return "Fora da pasta de usuário" }
        if roots.values.contains(where: { $0.contains(path) }) { return "Pasta protegida" }
        guard (roots[category] ?? []).contains(where: { Self.isStrictlyInside(path, $0) }) else {
            return "Fora das pastas permitidas"
        }
        return nil
    }

    private static func isStrictlyInside(_ path: [String], _ ancestor: [String]) -> Bool {
        path.count > ancestor.count && Array(path.prefix(ancestor.count)) == ancestor
    }
}

/// Moves confirmed items to the Trash (or deletes items already in it), reporting each step.
public struct Cleaner: Sendable {
    private let safety: CleanupSafety
    private let remover: any FileRemoving

    public init(safety: CleanupSafety, remover: any FileRemoving = SystemFileRemover()) {
        self.safety = safety
        self.remover = remover
    }

    /// Runs off the main actor. Cancelling the calling task stops after the current item;
    /// `.finished` is still emitted with what was done.
    public func clean(
        _ plan: [CleanupPlanEntry],
        progress: (CleanupEvent) -> Void
    ) async -> CleanupSummary {
        run(plan, isCancelled: { Task.isCancelled }, emit: progress)
    }

    func run(
        _ plan: [CleanupPlanEntry],
        isCancelled: () -> Bool,
        emit: (CleanupEvent) -> Void
    ) -> CleanupSummary {
        var summary = CleanupSummary()
        let total = plan.reduce(0) { $0 + $1.items.count }
        var index = 0

        for entry in plan {
            if isCancelled() {
                summary.wasCancelled = true
                break
            }

            let action = CleanupAction.for(entry.category)
            var removed: Int64 = 0
            var failures = 0
            emit(.categoryStarted(entry.category))

            for item in entry.items {
                if isCancelled() {
                    summary.wasCancelled = true
                    break
                }
                emit(.itemStarted(entry.category, item: item, index: index, total: total))
                index += 1

                let reason: String?
                if let refusal = safety.refusal(for: item.url, in: entry.category) {
                    reason = refusal
                } else {
                    do {
                        try remover.perform(action, on: item.url)
                        reason = nil
                    } catch {
                        reason = Self.describe(error)
                    }
                }

                if let reason {
                    failures += 1
                    summary.failures.append(CleanupFailure(category: entry.category, item: item, reason: reason))
                    emit(.itemFailed(entry.category, item: item, reason: reason))
                } else {
                    removed += item.size
                    switch action {
                    case .moveToTrash:
                        summary.trashedBytes += item.size
                        summary.trashedCount += 1
                    case .delete:
                        summary.deletedBytes += item.size
                        summary.deletedCount += 1
                    }
                    emit(.itemFinished(entry.category, item: item))
                }
            }

            emit(.categoryFinished(entry.category, removedBytes: removed, failures: failures))
            if summary.wasCancelled { break }
        }

        emit(.finished(summary))
        return summary
    }

    static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileNoSuchFileError, NSFileReadNoSuchFileError:
                return "O item não existe mais"
            case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
                return "Permissão negada"
            case NSFileWriteVolumeReadOnlyError:
                return "Volume somente leitura"
            default:
                break
            }
        }

        let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) ?? nsError
        if posix.domain == NSPOSIXErrorDomain {
            switch Int32(posix.code) {
            case EBUSY: return "Em uso por outro processo"
            case EACCES, EPERM: return "Permissão negada"
            case ENOENT: return "O item não existe mais"
            default: break
            }
        }
        return nsError.localizedDescription
    }
}
