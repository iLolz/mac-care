import CleanerKit
import Foundation
import Observation

/// Drives the cleanup sheet: review the selection, clean with live progress, show the result.
@MainActor
@Observable
final class CleanupViewModel: Identifiable {
    enum Phase {
        case review
        case cleaning
        case done
    }

    enum StepState {
        case pending
        case running
        case done
    }

    struct Group: Identifiable {
        let category: CleanupCategory
        let items: [ScanItem]

        var id: CategoryID { category.id }
        var totalSize: Int64 { items.reduce(0) { $0 + $1.size } }
    }

    private struct Pending {
        var items = 0
        var bytes: Int64 = 0
        var failures: [CategoryID: Int] = [:]
        var current: URL?
    }

    /// The UI is refreshed at most this often while items fly by.
    private static let publishInterval: TimeInterval = 0.05

    let groups: [Group]
    /// Disk usage when the sheet opened, for the before/after comparison.
    let volumeBefore: VolumeUsage?
    private let cleaner: Cleaner

    private(set) var phase: Phase = .review
    private(set) var excluded: Set<URL> = []

    private(set) var plan: [Group] = []
    private(set) var totalItems = 0
    private(set) var totalBytes: Int64 = 0
    private(set) var steps: [CategoryID: StepState] = [:]
    private(set) var stepRemovedBytes: [CategoryID: Int64] = [:]
    private(set) var stepFailures: [CategoryID: Int] = [:]
    private(set) var processedItems = 0
    private(set) var processedBytes: Int64 = 0
    private(set) var currentCategory: CategoryID?
    private(set) var currentItem: URL?
    private(set) var isCancelling = false
    private(set) var summary: CleanupSummary?

    @ObservationIgnored private var worker: Task<Void, Never>?
    @ObservationIgnored private var pending = Pending()
    @ObservationIgnored private var lastPublish = Date.distantPast

    init(groups: [Group], volume: VolumeUsage?, cleaner: Cleaner) {
        self.groups = groups
        self.volumeBefore = volume
        self.cleaner = cleaner
    }

    convenience init(scan: ScanViewModel) {
        let groups = scan.selectedCategories.compactMap { category -> Group? in
            guard let items = scan.result(for: category)?.items, !items.isEmpty else { return nil }
            return Group(category: category, items: items)
        }
        self.init(
            groups: groups,
            volume: scan.volume,
            cleaner: Cleaner(safety: CleanupSafety(categories: scan.categories))
        )
    }

    // MARK: Review

    func isIncluded(_ item: ScanItem) -> Bool {
        !excluded.contains(item.url)
    }

    func toggle(_ item: ScanItem) {
        if excluded.contains(item.url) {
            excluded.remove(item.url)
        } else {
            excluded.insert(item.url)
        }
    }

    func includedItems(in group: Group) -> [ScanItem] {
        group.items.filter { isIncluded($0) }
    }

    func isIncluded(_ group: Group) -> Bool {
        group.items.contains { isIncluded($0) }
    }

    /// Unchecks every item of a group that has any checked, otherwise checks them all.
    func toggle(_ group: Group) {
        let urls = group.items.map(\.url)
        if isIncluded(group) {
            excluded.formUnion(urls)
        } else {
            excluded.subtract(urls)
        }
    }

    var includedGroups: [Group] {
        groups.compactMap { group in
            let items = includedItems(in: group)
            return items.isEmpty ? nil : Group(category: group.category, items: items)
        }
    }

    var includesTrash: Bool {
        groups.contains { $0.id == .trash && isIncluded($0) }
    }

    // MARK: Cleaning

    func start() {
        guard phase == .review else { return }
        let plan = includedGroups
        guard !plan.isEmpty else { return }

        self.plan = plan
        totalItems = plan.reduce(0) { $0 + $1.items.count }
        totalBytes = plan.reduce(0) { $0 + $1.totalSize }
        steps = Dictionary(uniqueKeysWithValues: plan.map { ($0.id, StepState.pending) })
        phase = .cleaning

        let entries = plan.map {
            CleanupPlanEntry(category: $0.id, title: $0.category.title, items: $0.items)
        }
        let (events, continuation) = AsyncStream.makeStream(of: CleanupEvent.self)
        let cleaner = cleaner
        worker = Task.detached(priority: .userInitiated) {
            _ = await cleaner.clean(entries) { continuation.yield($0) }
            continuation.finish()
        }
        Task {
            for await event in events {
                apply(event)
            }
        }
    }

    /// Stops after the item being processed; what was already done is kept and reported.
    func cancel() {
        guard phase == .cleaning, !isCancelling else { return }
        isCancelling = true
        worker?.cancel()
    }

    var progress: Double {
        if totalBytes > 0 { return min(Double(processedBytes) / Double(totalBytes), 1) }
        return totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0
    }

    func state(of group: Group) -> StepState {
        steps[group.id] ?? .pending
    }

    private func apply(_ event: CleanupEvent) {
        switch event {
        case .categoryStarted(let id):
            publish()
            currentCategory = id
            currentItem = nil
            steps[id] = .running
        case .itemStarted(_, let item, _, _):
            pending.current = item.url
        case .itemFinished(_, let item):
            pending.items += 1
            pending.bytes += item.size
        case .itemFailed(let id, let item, _):
            pending.items += 1
            pending.bytes += item.size
            pending.failures[id, default: 0] += 1
        case .categoryFinished(let id, let removedBytes, let failures):
            publish()
            steps[id] = .done
            stepRemovedBytes[id] = removedBytes
            stepFailures[id] = failures
        case .finished(let result):
            publish()
            currentCategory = nil
            currentItem = nil
            summary = result
            phase = .done
            worker = nil
        }

        if Date().timeIntervalSince(lastPublish) >= Self.publishInterval {
            publish()
        }
    }

    /// Moves the counters gathered since the last refresh into observed state.
    private func publish() {
        lastPublish = Date()
        if pending.items > 0 {
            processedItems += pending.items
            processedBytes += pending.bytes
        }
        for (id, count) in pending.failures {
            stepFailures[id, default: 0] += count
        }
        if let current = pending.current, phase == .cleaning {
            currentItem = current
        }
        pending = Pending()
    }
}
