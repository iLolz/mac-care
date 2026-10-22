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
    private(set) var hasFullDiskAccess = FullDiskAccess.isGranted()
    private(set) var isScanning = false
    private(set) var lastScan: Date?

    private let scanner = DiskScanner()

    init(categories: [CleanupCategory] = CleanupCategory.catalog()) {
        self.categories = categories
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

    func refreshVolume() {
        volume = try? VolumeUsage.current()
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
