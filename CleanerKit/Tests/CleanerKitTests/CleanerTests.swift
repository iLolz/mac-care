import XCTest
@testable import CleanerKit

private final class FakeRemover: FileRemoving, @unchecked Sendable {
    struct Call: Equatable {
        let action: CleanupAction
        let url: URL
    }

    private let lock = NSLock()
    private var recorded: [Call] = []
    private let failing: Set<URL>

    init(failing: Set<URL> = []) {
        self.failing = failing
    }

    var calls: [Call] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func perform(_ action: CleanupAction, on url: URL) throws {
        lock.lock()
        recorded.append(Call(action: action, url: url))
        lock.unlock()
        if failing.contains(url) {
            throw CocoaError(.fileWriteNoPermission)
        }
    }
}

final class CleanerTests: XCTestCase {
    private var home: URL!
    private var categories: [CleanupCategory]!

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        for folder in ["Library/Caches", "Library/Logs", ".Trash", "Documents", "Projects/web"] {
            try FileManager.default.createDirectory(
                at: home.appendingPathComponent(folder), withIntermediateDirectories: true
            )
        }
        categories = CleanupCategory.catalog(home: home)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
    }

    private func item(_ relative: String, size: Int64 = 100) -> ScanItem {
        ScanItem(url: home.appendingPathComponent(relative), size: size)
    }

    private func cleaner(_ remover: any FileRemoving) -> Cleaner {
        Cleaner(safety: CleanupSafety(home: home, categories: categories), remover: remover)
    }

    func testEventsArriveInOrder() async {
        let a = item("Library/Caches/a", size: 300)
        let b = item("Library/Caches/b", size: 200)
        let log = item("Library/Logs/app.log", size: 50)
        let plan = [
            CleanupPlanEntry(category: .userCaches, title: "Caches de apps", items: [a, b]),
            CleanupPlanEntry(category: .logs, title: "Logs", items: [log]),
        ]

        var events: [CleanupEvent] = []
        let summary = await cleaner(FakeRemover()).clean(plan) { events.append($0) }

        XCTAssertEqual(events, [
            .categoryStarted(.userCaches),
            .itemStarted(.userCaches, item: a, index: 0, total: 3),
            .itemFinished(.userCaches, item: a),
            .itemStarted(.userCaches, item: b, index: 1, total: 3),
            .itemFinished(.userCaches, item: b),
            .categoryFinished(.userCaches, removedBytes: 500, failures: 0),
            .categoryStarted(.logs),
            .itemStarted(.logs, item: log, index: 2, total: 3),
            .itemFinished(.logs, item: log),
            .categoryFinished(.logs, removedBytes: 50, failures: 0),
            .finished(summary),
        ])
        XCTAssertEqual(summary.trashedBytes, 550)
        XCTAssertEqual(summary.trashedCount, 3)
        XCTAssertEqual(summary.deletedBytes, 0)
        XCTAssertTrue(summary.failures.isEmpty)
        XCTAssertFalse(summary.wasCancelled)
    }

    func testFailuresAreReportedAndCleaningContinues() async {
        let locked = item("Library/Caches/locked", size: 300)
        let ok = item("Library/Caches/ok", size: 200)
        let plan = [CleanupPlanEntry(category: .userCaches, title: "Caches", items: [locked, ok])]

        var events: [CleanupEvent] = []
        let summary = await cleaner(FakeRemover(failing: [locked.url])).clean(plan) { events.append($0) }

        XCTAssertTrue(events.contains(.itemFailed(.userCaches, item: locked, reason: "Permissão negada")))
        XCTAssertTrue(events.contains(.itemFinished(.userCaches, item: ok)))
        XCTAssertTrue(events.contains(.categoryFinished(.userCaches, removedBytes: 200, failures: 1)))
        XCTAssertEqual(summary.failures, [
            CleanupFailure(category: .userCaches, item: locked, reason: "Permissão negada"),
        ])
        XCTAssertEqual(summary.trashedBytes, 200)
    }

    func testMissingItemFailsWithRealRemover() async {
        let missing = item(".Trash/does-not-exist")
        let plan = [CleanupPlanEntry(category: .trash, title: "Lixeira", items: [missing])]

        let summary = await cleaner(SystemFileRemover()).clean(plan) { _ in }

        XCTAssertEqual(summary.failures.count, 1)
        XCTAssertEqual(summary.failures.first?.item, missing)
        XCTAssertFalse(summary.failures.first?.reason.isEmpty ?? true)
        XCTAssertEqual(summary.deletedCount, 0)
    }

    func testTrashItemsAreDeletedAndOthersTrashed() async {
        let cache = item("Library/Caches/a", size: 10)
        let trashed = item(".Trash/old.zip", size: 20)
        let plan = [
            CleanupPlanEntry(category: .userCaches, title: "Caches", items: [cache]),
            CleanupPlanEntry(category: .trash, title: "Lixeira", items: [trashed]),
        ]
        let remover = FakeRemover()

        let summary = await cleaner(remover).clean(plan) { _ in }

        XCTAssertEqual(remover.calls, [
            FakeRemover.Call(action: .moveToTrash, url: cache.url),
            FakeRemover.Call(action: .delete, url: trashed.url),
        ])
        XCTAssertEqual(summary.trashedBytes, 10)
        XCTAssertEqual(summary.deletedBytes, 20)
        XCTAssertEqual(summary.removedBytes, 30)
    }

    func testRefusedItemsNeverReachTheRemover() async {
        let outside = ScanItem(url: URL(fileURLWithPath: "/etc/hosts"), size: 10)
        let root = item("Library/Caches", size: 10)
        let plan = [CleanupPlanEntry(category: .userCaches, title: "Caches", items: [outside, root])]
        let remover = FakeRemover()

        let summary = await cleaner(remover).clean(plan) { _ in }

        XCTAssertTrue(remover.calls.isEmpty)
        XCTAssertEqual(summary.failures.map(\.item), [outside, root])
        XCTAssertEqual(summary.removedBytes, 0)
    }

    func testCancellationStopsAfterCurrentItem() {
        let items = (0..<5).map { item("Library/Caches/\($0)") }
        let plan = [
            CleanupPlanEntry(category: .userCaches, title: "Caches", items: items),
            CleanupPlanEntry(category: .logs, title: "Logs", items: [item("Library/Logs/x")]),
        ]
        let remover = FakeRemover()

        final class Log {
            var events: [CleanupEvent] = []
            var finishedItems = 0
        }
        let log = Log()
        let summary = cleaner(remover).run(plan, isCancelled: { log.finishedItems >= 2 }) { event in
            log.events.append(event)
            if case .itemFinished = event { log.finishedItems += 1 }
        }
        let events = log.events

        XCTAssertEqual(remover.calls.count, 2)
        XCTAssertTrue(summary.wasCancelled)
        XCTAssertEqual(summary.trashedCount, 2)
        XCTAssertFalse(events.contains(.categoryStarted(.logs)))
        XCTAssertEqual(Array(events.suffix(2)), [
            .categoryFinished(.userCaches, removedBytes: 200, failures: 0),
            .finished(summary),
        ])
    }

    func testSafetyAllowsOnlyChildrenOfTheCategoryRoots() {
        let safety = CleanupSafety(home: home, categories: categories)
        let url = { (relative: String) in self.home.appendingPathComponent(relative) }

        XCTAssertNil(safety.refusal(for: url("Library/Caches/com.spotify.client"), in: .userCaches))
        XCTAssertNil(safety.refusal(for: url(".Trash/old.zip"), in: .trash))
        XCTAssertNil(safety.refusal(for: url("Projects/web/node_modules"), in: .nodeModules))

        XCTAssertNotNil(safety.refusal(for: URL(fileURLWithPath: "/etc/hosts"), in: .userCaches))
        XCTAssertNotNil(safety.refusal(for: home, in: .userCaches))
        XCTAssertNotNil(safety.refusal(for: url("Library/Caches"), in: .userCaches))
        XCTAssertNotNil(safety.refusal(for: url(".Trash"), in: .trash))
        XCTAssertNotNil(safety.refusal(for: url("Documents/report.pdf"), in: .userCaches))
        XCTAssertNotNil(safety.refusal(for: url("Library/Caches/../../Documents"), in: .userCaches))
        // A cache item handed to the Trash category would be deleted for good: refuse it.
        XCTAssertNotNil(safety.refusal(for: url("Library/Caches/a"), in: .trash))
        XCTAssertNotNil(safety.refusal(for: URL(string: "https://example.com/a")!, in: .userCaches))
    }
}
