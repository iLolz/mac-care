import Foundation

public struct ScanItem: Hashable, Sendable {
    public let url: URL
    /// Allocated size on disk, in bytes.
    public let size: Int64

    public init(url: URL, size: Int64) {
        self.url = url
        self.size = size
    }
}

public struct CategoryScanResult: Identifiable, Sendable {
    public var id: CategoryID { category }
    public let category: CategoryID
    /// Removable items, largest first.
    public let items: [ScanItem]
    /// Folders that exist but could not be read (usually missing Full Disk Access).
    public let unreadableFolders: [URL]

    public var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
}

/// Measures how much space each cleanup category would free. Read-only: never deletes anything.
public struct DiskScanner: Sendable {
    public init() {}

    public func scan(_ category: CleanupCategory) -> CategoryScanResult {
        var items: [ScanItem] = []
        var unreadable: [URL] = []

        for rule in category.rules {
            let candidates: [URL]
            switch rule.kind {
            case .contents:
                candidates = children(of: rule.root, skipHidden: false, unreadable: &unreadable)
            case .olderThan(let days):
                let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
                candidates = children(of: rule.root, skipHidden: true, unreadable: &unreadable)
                    .filter { lastTouched($0) < cutoff }
            case .namedDirectories(let name, let maxDepth):
                candidates = directories(named: name, under: rule.root, maxDepth: maxDepth)
            }

            for url in candidates {
                let size = allocatedSize(of: url)
                if size > 0 {
                    items.append(ScanItem(url: url, size: size))
                }
            }
        }

        items.sort { $0.size > $1.size }
        return CategoryScanResult(category: category.id, items: items, unreadableFolders: unreadable)
    }

    func children(of directory: URL, skipHidden: Bool, unreadable: inout [URL]) -> [URL] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        do {
            return try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
                options: skipHidden ? [.skipsHiddenFiles] : []
            )
        } catch {
            unreadable.append(directory)
            return []
        }
    }

    /// The most recent of the item's modification and creation dates.
    func lastTouched(_ url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
        return max(values?.contentModificationDate ?? .distantPast, values?.creationDate ?? .distantPast)
    }

    func directories(named name: String, under root: URL, maxDepth: Int) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]
        var found: [URL] = []

        func walk(_ directory: URL, depth: Int) {
            guard depth <= maxDepth,
                  let children = try? FileManager.default.contentsOfDirectory(
                      at: directory, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]
                  )
            else { return }

            for child in children {
                guard let values = try? child.resourceValues(forKeys: Set(keys)),
                      values.isDirectory == true,
                      values.isSymbolicLink != true,
                      values.isPackage != true
                else { continue }

                if child.lastPathComponent == name {
                    // Don't descend: nested node_modules are already counted in the outer one.
                    found.append(child)
                } else {
                    walk(child, depth: depth + 1)
                }
            }
        }

        walk(root, depth: 0)
        return found
    }

    func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        ]
        guard let values = try? url.resourceValues(forKeys: keys), values.isSymbolicLink != true else {
            return 0
        }
        guard values.isDirectory == true else {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let fileValues = try? file.resourceValues(forKeys: keys),
                  fileValues.isRegularFile == true
            else { continue }
            total += Int64(fileValues.totalFileAllocatedSize ?? fileValues.fileAllocatedSize ?? 0)
        }
        return total
    }
}
