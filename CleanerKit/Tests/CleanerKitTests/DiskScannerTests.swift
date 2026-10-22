import XCTest
@testable import CleanerKit

final class DiskScannerTests: XCTestCase {
    private var root: URL!
    private let scanner = DiskScanner()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ relative: String, bytes: Int, touched: Date? = nil) throws {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data(repeating: 1, count: bytes).write(to: url)
        if let touched {
            try FileManager.default.setAttributes(
                [.modificationDate: touched, .creationDate: touched], ofItemAtPath: url.path
            )
        }
    }

    private func category(_ kind: ScanRule.Kind, at relative: String) -> CleanupCategory {
        CleanupCategory(
            id: .userCaches, title: "Teste", summary: "", symbol: "folder",
            rules: [ScanRule(root: root.appendingPathComponent(relative), kind: kind)]
        )
    }

    func testContentsRuleReturnsTopLevelItemsLargestFirst() throws {
        try write("Caches/small.bin", bytes: 10_000)
        try write("Caches/app/a.bin", bytes: 50_000)
        try write("Caches/app/nested/b.bin", bytes: 50_000)

        let result = scanner.scan(category(.contents, at: "Caches"))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), ["app", "small.bin"])
        XCTAssertGreaterThanOrEqual(result.items[0].size, 100_000)
        XCTAssertGreaterThanOrEqual(result.items[1].size, 10_000)
        XCTAssertEqual(result.totalSize, result.items[0].size + result.items[1].size)
        XCTAssertTrue(result.unreadableFolders.isEmpty)
    }

    func testMissingFolderYieldsEmptyResult() {
        let result = scanner.scan(category(.contents, at: "DoesNotExist"))
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertTrue(result.unreadableFolders.isEmpty)
    }

    func testOlderThanRuleSkipsRecentFiles() throws {
        let old = Date().addingTimeInterval(-60 * 86_400)
        try write("Downloads/old.zip", bytes: 20_000, touched: old)
        try write("Downloads/new.zip", bytes: 20_000)

        let result = scanner.scan(category(.olderThan(days: 30), at: "Downloads"))

        XCTAssertEqual(result.items.map(\.url.lastPathComponent), ["old.zip"])
    }

    func testNamedDirectoriesFindsOuterNodeModulesWithinDepth() throws {
        try write("Projects/web/node_modules/react/index.js", bytes: 5_000)
        try write("Projects/web/node_modules/react/node_modules/x/index.js", bytes: 5_000)
        try write("Projects/a/b/c/d/e/f/node_modules/too-deep.js", bytes: 5_000)

        let result = scanner.scan(
            category(.namedDirectories(name: "node_modules", maxDepth: 4), at: "Projects")
        )

        XCTAssertEqual(result.items.count, 1)
        XCTAssertEqual(result.items.first?.url.deletingLastPathComponent().lastPathComponent, "web")
    }

    func testSymlinksAreNotFollowed() throws {
        try write("Elsewhere/big.bin", bytes: 100_000)
        let caches = root.appendingPathComponent("Caches")
        try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: caches.appendingPathComponent("link"),
            withDestinationURL: root.appendingPathComponent("Elsewhere")
        )

        let result = scanner.scan(category(.contents, at: "Caches"))

        XCTAssertTrue(result.items.isEmpty)
    }

    func testCatalogHasEveryCategoryOnce() {
        let ids = CleanupCategory.catalog(home: root).map(\.id)
        XCTAssertEqual(Set(ids), Set(CategoryID.allCases))
        XCTAssertEqual(ids.count, CategoryID.allCases.count)
    }

    func testVolumeUsageFractions() {
        let usage = VolumeUsage(totalBytes: 1_000, availableBytes: 250)
        XCTAssertEqual(usage.usedBytes, 750)
        XCTAssertEqual(usage.freeFraction, 0.25, accuracy: 0.0001)
    }
}
