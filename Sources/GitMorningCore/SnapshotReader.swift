import Foundation

public struct SnapshotKey: Hashable, Sendable {
    public let period: String
    public let language: String
    public init(period: String, language: String) throws {
        guard ["daily", "weekly"].contains(period), ["all", "Python", "TypeScript", "JavaScript", "Swift", "Go", "Rust"].contains(language) else { throw SnapshotError.invalidSnapshot }
        self.period = period; self.language = language
    }
    public var filename: String { "\(period)-\(language.lowercased()).json" }
    public func decode(_ data: Data) throws -> TrendSnapshot {
        let snapshot = try TrendSnapshot.decode(data)
        guard snapshot.period == period, snapshot.languageFilter == language else { throw SnapshotError.invalidSnapshot }
        return snapshot
    }
}

public struct FeedEndpoint: Sendable {
    public let baseURL: URL
    public init(_ address: String) throws {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "https", let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              let url = parts.url else { throw SnapshotError.invalidSource }
        baseURL = url
    }
    public func url(for key: SnapshotKey) -> URL { baseURL.appendingPathComponent(key.filename) }
    public func url(file name: String) -> URL { baseURL.appendingPathComponent(name) }
}

public struct SnapshotCache {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public func load(_ key: SnapshotKey) throws -> Data? {
        let path = directory.appendingPathComponent(key.filename)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let data = try Data(contentsOf: path)
        _ = try key.decode(data)
        return data
    }
    public func save(_ data: Data, for key: SnapshotKey) throws {
        let incoming = try key.decode(data)
        if let existing = try? load(key), let old = try? key.decode(existing),
           let oldDate = old.collectedDate, let date = incoming.collectedDate, date < oldDate {
            throw SnapshotReadError.olderSnapshot
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(key.filename), options: .atomic)
    }
}

public enum SnapshotReadError: Error { case invalidHTTPResponse, oversizedResponse, olderSnapshot }

/// Which redirects the feed reader follows. Only a move of the same file to another HTTPS host, such as
/// GitHub Pages sending `ddingddong9.github.io/gitmorning/v1/…` to a custom domain once one is connected.
/// Everything the reader gets is still decoded and checked; any other redirect fails the request.
public enum FeedRedirect {
    public static func allows(from old: URL?, to new: URL?) -> Bool {
        guard let old, let new,
              let before = URLComponents(url: old, resolvingAgainstBaseURL: false),
              let after = URLComponents(url: new, resolvingAgainstBaseURL: false),
              after.scheme == "https", let host = after.host, !host.isEmpty,
              after.user == nil, after.password == nil, after.query == nil, after.fragment == nil
        else { return false }
        // GitHub Pages keeps the path when it moves a project site to a custom domain, except for the
        // repository prefix ("/gitmorning/v1/x.json" → "/v1/x.json"), so the new path must end with the old file path.
        let file = before.path.split(separator: "/").suffix(2).joined(separator: "/")
        return !file.isEmpty && (after.path == before.path || after.path.hasSuffix("/" + file))
    }
}

private final class FeedRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(FeedRedirect.allows(from: task.originalRequest?.url, to: request.url) ? request : nil)
    }
}

public actor SnapshotHTTPReader {
    private let session: URLSession
    init(session: URLSession) { self.session = session }
    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 25
        configuration.httpCookieStorage = nil
        session = URLSession(configuration: configuration, delegate: FeedRedirects(), delegateQueue: nil)
    }
    public func load(_ key: SnapshotKey, endpoint: FeedEndpoint) async throws -> Data {
        var request = URLRequest(url: endpoint.url(for: key))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SnapshotReadError.invalidHTTPResponse }
        guard data.count <= 3_000_000 else { throw SnapshotReadError.oversizedResponse }
        _ = try key.decode(data)
        try Task.checkCancellation()
        return data
    }

    /// The daily rank history for `language` from the shared feed, checked with `TrendHistory.decode`.
    public func loadHistory(language: String, endpoint: FeedEndpoint) async throws -> Data {
        var request = URLRequest(url: endpoint.url(file: TrendHistory.filename(language: language)))
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SnapshotReadError.invalidHTTPResponse }
        guard data.count <= 3_000_000 else { throw SnapshotReadError.oversizedResponse }
        _ = try TrendHistory.decode(data, language: language)
        try Task.checkCancellation()
        return data
    }
}

public struct SavedCatalog: Codable {
    public var version = 1
    public var bookmarks: [Bookmark]
    public var repositories: [String: Repository]
    public init(bookmarks: [Bookmark] = [], repositories: [String: Repository] = [:]) {
        self.bookmarks = bookmarks; self.repositories = repositories
    }
}

public struct SavedCatalogStorage {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> SavedCatalog? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let catalog = try JSONDecoder().decode(SavedCatalog.self, from: Data(contentsOf: url))
        guard catalog.version == 1 else { throw SnapshotError.unsupportedVersion }
        return catalog
    }
    public func save(_ catalog: SavedCatalog) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(catalog).write(to: url, options: .atomic)
    }
}
