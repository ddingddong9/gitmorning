import XCTest
@testable import GitMorningCore

final class CatalogTests: XCTestCase {
    func testFilterCombinesLanguageQueryAndBookmarkScope() {
        let saved = [Bookmark(repositoryID: "docnest")]
        XCTAssertEqual(Catalog.filter(Repository.samples, feed: .saved, language: "Python", query: " 문서 ", bookmarks: saved).map(\.id), ["docnest"])
        XCTAssertTrue(Catalog.filter(Repository.samples, feed: .saved, language: "Rust", query: "", bookmarks: saved).isEmpty)
        XCTAssertEqual(Catalog.filter(Repository.samples, feed: .daily, language: nil, query: "OPENKIT", bookmarks: []).map(\.id), ["docnest"])
    }

    func testTrendingPreservesSuppliedSourceOrder() {
        let source = Array(Repository.samples.reversed())
        XCTAssertEqual(Catalog.filter(source, feed: .weekly, language: nil, query: "", bookmarks: []).map(\.id), source.map(\.id))
    }

    func testBookmarksSortNewestFirstAndDuplicateIDsDoNotCrash() {
        let saved = [Bookmark(repositoryID: "docnest", savedAt: Date(timeIntervalSince1970: 1)), Bookmark(repositoryID: "flowline", savedAt: Date(timeIntervalSince1970: 2)), Bookmark(repositoryID: "docnest", savedAt: Date(timeIntervalSince1970: 3))]
        XCTAssertEqual(Catalog.filter(Repository.samples, feed: .saved, language: nil, query: "", bookmarks: saved).map(\.id), ["docnest", "flowline"])
    }

    func testStoragePersistsAndRejectsCorruptData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = BookmarkStorage(url: directory.appendingPathComponent("nested/bookmarks.json"))
        XCTAssertEqual(try storage.load(), [])
        let records = [Bookmark(repositoryID: "docnest", savedAt: Date(timeIntervalSince1970: 123))]
        try storage.save(records)
        XCTAssertEqual(try storage.load(), records)
        try Data("broken".utf8).write(to: storage.url)
        XCTAssertThrowsError(try storage.load())
    }
}
