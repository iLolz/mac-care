import CleanerKit
import Foundation
import Observation

@MainActor
@Observable
final class ScanViewModel {
    enum CategoryState {
        case idle
        case scanning
        case done(CategoryScanResult)
    }

    let categories: [CleanupCategory]
    private(set) var states: [CategoryID: CategoryState] = [:]
    private(set) var volume: VolumeUsage?
    private(set) var volumeName: String?
    private(set) var hasFullDiskAccess = FullDiskAccess.isGranted()
    private(set) var isScanning = false
    private(set) var lastScan: Date?
    private(set) var selected: Set<CategoryID>

    /// Categories that can hold files people still want, so they need explicit opt-in.
    static let optInCategories: Set<CategoryID> = [.oldDownloads, .nodeModules]

    private let scanner = DiskScanner()

    init(categories: [CleanupCategory] = CleanupCategory.catalog()) {
        self.categories = categories
        self.selected = Set(categories.map(\.id)).subtracting(Self.optInCategories)
        refreshVolume()
    }

    var recoverableBytes: Int64 {
        states.values.reduce(0) { total, state in
            if case .done(let result) = state { return total + result.totalSize }
            return total
        }
    }

    func state(for category: CleanupCategory) -> CategoryState {
        states[category.id] ?? .idle
    }

    var selectedCategories: [CleanupCategory] {
        categories.filter { isSelected($0) }
    }

    var selectedBytes: Int64 {
        selectedCategories.reduce(Int64(0)) { $0 + (result(for: $1)?.totalSize ?? 0) }
    }

    var lockedCount: Int {
        categories.filter { isLocked($0) }.count
    }

    func result(for category: CleanupCategory) -> CategoryScanResult? {
        if case .done(let result) = state(for: category) { return result }
        return nil
    }

    /// Nothing could be read: every folder in the category needs Full Disk Access.
    func isLocked(_ category: CleanupCategory) -> Bool {
        guard let scan = result(for: category) else { return false }
        return scan.items.isEmpty && !scan.unreadableFolders.isEmpty
    }

    func isSelected(_ category: CleanupCategory) -> Bool {
        selected.contains(category.id) && !isLocked(category)
    }

    func toggle(_ category: CleanupCategory) {
        if selected.contains(category.id) {
            selected.remove(category.id)
        } else {
            selected.insert(category.id)
        }
    }

    func refreshVolume() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        volume = try? VolumeUsage.current(for: home)
        volumeName = (try? home.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName
    }

    func refreshAccess() {
        hasFullDiskAccess = FullDiskAccess.isGranted()
    }

    func scan() async {
        guard !isScanning else { return }
        isScanning = true
        refreshAccess()
        refreshVolume()
        for category in categories {
            states[category.id] = .scanning
        }

        let scanner = scanner
        await withTaskGroup(of: CategoryScanResult.self) { group in
            for category in categories {
                group.addTask { scanner.scan(category) }
            }
            for await result in group {
                states[result.category] = .done(result)
            }
        }

        lastScan = Date()
        isScanning = false
    }
}
