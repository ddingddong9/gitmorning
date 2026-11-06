import XCTest
@testable import GitMorningCore

final class LocalSummaryTests: XCTestCase {
    func testCacheSurvivesRestartAndInvalidatesChangedInputOrModel() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = LocalSummaryStorage(directory: directory)
        let item = LocalSummary(repositoryID: "owner/tool", description: "A tool", text: "도구 설명", sourceURL: URL(string: "https://api.github.com/repos/owner/tool/readme")!, sourceHash: LocalSummary.hash("README v1"), modelVersion: "test-model")
        try storage.save(item)
        let reloaded = LocalSummaryStorage(directory: directory)
        XCTAssertEqual(try reloaded.load(repositoryID: item.repositoryID, description: "A tool", modelVersion: "test-model"), item)
        XCTAssertNil(try reloaded.load(repositoryID: item.repositoryID, description: "Changed description", modelVersion: "test-model"))
        XCTAssertNil(try reloaded.load(repositoryID: item.repositoryID, description: "A tool", modelVersion: "new-model"))
        XCTAssertNil(try reloaded.load(repositoryID: "owner/other", description: "A tool", modelVersion: "test-model"))
        XCTAssertNotEqual(item.sourceHash, LocalSummary.hash("README v2"))
    }

    func testReadmeExcerptOmitsCodeAndBoundsMultilingualInput() {
        let excerpt = ReadmeDocument.excerpt("# Tool\n```sh\nrm something\n```\nUseful description\n![badge](url)")
        XCTAssertTrue(excerpt.contains("Useful description"))
        XCTAssertFalse(excerpt.contains("rm something"))
        XCTAssertFalse(excerpt.contains("badge"))
        XCTAssertEqual(ReadmeDocument.excerpt(String(repeating: "한", count: 10_000)).count, 2000)
        XCTAssertEqual(ReadmeDocument.excerpt(String(repeating: "a", count: 10_000)).count, 4500)
        let decorated = "<picture><img alt=\"Star History\" src=\"badge\"></picture>\n<a href=\"docs/README.ko.md\">한국어</a> •\n<h4>A useful tool</h4>\n<p>Preserves context across sessions.</p>"
        let meaningful = ReadmeDocument.excerpt(decorated)
        XCTAssertFalse(meaningful.contains("Star History"))
        XCTAssertFalse(meaningful.contains("한국어"))
        XCTAssertTrue(meaningful.contains("Preserves context across sessions."))
    }
}
