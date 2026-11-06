import XCTest
@testable import GitMorningCore

final class SnapshotReaderTests: XCTestCase {
    private func payload(period: String = "daily", language: String = "all", date: String = "2026-11-02T02:35:30.153577+00:00") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "period": period, "languageFilter": language,
            "sourceURL": "https://github.com/trending" + (language == "all" ? "" : "/" + language.lowercased()) + "?since=" + period,
            "collectedAt": date, "status": "complete",
            "repositories": [["id": "example/tool", "owner": "example", "name": "tool", "url": "https://github.com/example/tool", "rank": 1, "description": "Original description", "language": NSNull(), "stars": NSNull(), "periodStars": 12, "summaryStatus": "pending"]]
        ])
    }

    func testEndpointRejectsCredentialsQueryAndNonHTTPS() throws {
        for url in ["http://example.com", "https://name:secret@example.com", "https://example.com?token=secret", "https://example.com/#fragment"] {
            XCTAssertThrowsError(try FeedEndpoint(url))
        }
        let key = try SnapshotKey(period: "weekly", language: "Python")
        XCTAssertEqual(try FeedEndpoint("https://example.com/snapshots/").url(for: key).absoluteString, "https://example.com/snapshots/weekly-python.json")
        XCTAssertThrowsError(try SnapshotKey(period: "daily", language: "../private"))
    }

    func testWrongPeriodCannotPopulateCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SnapshotCache(directory: directory)
        let key = try SnapshotKey(period: "daily", language: "all")
        let data = try payload()
        try cache.save(data, for: key)
        XCTAssertThrowsError(try cache.save(payload(period: "weekly"), for: key))
        XCTAssertThrowsError(try cache.save(payload(language: "Python"), for: key))
        XCTAssertThrowsError(try cache.save(Data("broken".utf8), for: key))
        XCTAssertEqual(try cache.load(key), data)
    }

    func testOlderResponseDoesNotReplaceNewerCache() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let key = try SnapshotKey(period: "daily", language: "all")
        let cache = SnapshotCache(directory: directory)
        let data = try payload()
        try cache.save(data, for: key)
        XCTAssertThrowsError(try cache.save(payload(date: "2026-11-01T00:00:00Z"), for: key))
        XCTAssertEqual(try cache.load(key), data)
    }

    func testActualMappingKeepsMissingValuesAndPendingSummary() throws {
        let snapshot = try TrendSnapshot.decode(payload(period: "weekly"))
        let repo = try XCTUnwrap(Repository.from(snapshot).first)
        XCTAssertEqual(repo.id, "example/tool")
        XCTAssertEqual(repo.name, "tool")
        XCTAssertEqual(repo.fullName, "example/tool")
        XCTAssertNil(repo.stars)
        XCTAssertNil(repo.gain(for: .daily))
        XCTAssertEqual(repo.gain(for: .weekly), 12)
        XCTAssertFalse(repo.summaryAvailable)
        XCTAssertTrue(repo.features.isEmpty)
        XCTAssertEqual(repo.githubURL?.absoluteString, "https://github.com/example/tool")
    }

    func testSavedRepositorySurvivesWithoutCurrentFeed() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repo = Repository.from(try TrendSnapshot.decode(payload()))[0]
        let store = SavedCatalogStorage(url: directory.appendingPathComponent("saved.json"))
        try store.save(SavedCatalog(bookmarks: [Bookmark(repositoryID: repo.id)], repositories: [repo.id: repo]))
        let saved = try XCTUnwrap(store.load())
        XCTAssertEqual(saved.repositories[repo.id], repo)
        XCTAssertEqual(Catalog.filter(Array(saved.repositories.values), feed: .saved, language: nil, query: "", bookmarks: saved.bookmarks).map(\.id), [repo.id])
    }

    func testHTTPReaderRejectsErrorAndWrongPeriod() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [SnapshotMockProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let reader = SnapshotHTTPReader(session: session)
        let key = try SnapshotKey(period: "daily", language: "all")
        let endpoint = try FeedEndpoint("https://example.test/snapshots")
        SnapshotMockProtocol.reply = (503, try payload())
        do { _ = try await reader.load(key, endpoint: endpoint); XCTFail("503 accepted") } catch {}
        SnapshotMockProtocol.reply = (200, try payload(period: "weekly"))
        do { _ = try await reader.load(key, endpoint: endpoint); XCTFail("Wrong period accepted") } catch {}
        let data = try payload()
        SnapshotMockProtocol.reply = (200, data)
        let loaded = try await reader.load(key, endpoint: endpoint)
        XCTAssertEqual(loaded, data)
    }
}

private final class SnapshotMockProtocol: URLProtocol {
    static var reply: (Int, Data) = (500, Data())
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "example.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.reply
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
