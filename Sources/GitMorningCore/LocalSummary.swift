import Foundation
import CryptoKit

public struct LocalSummary: Codable, Equatable {
    public static let promptVersion = 3
    public let repositoryID: String
    public let description: String
    public let text: String
    public let sourceURL: URL
    public let sourceHash: String
    public let generatedAt: Date
    public let modelVersion: String
    public let version: Int
    public var overview: String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.contains("어떤 도구인가요") && $0 != "주요 기능" && $0 != "확인할 점" } ?? text
    }

    public init(repositoryID: String, description: String, text: String, sourceURL: URL, sourceHash: String, modelVersion: String) {
        self.repositoryID = repositoryID; self.description = description; self.text = text
        self.sourceURL = sourceURL; self.sourceHash = sourceHash; self.modelVersion = modelVersion
        generatedAt = Date(); version = Self.promptVersion
    }
    public static func hash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

public struct LocalSummaryStorage {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private func url(_ id: String) -> URL { directory.appendingPathComponent(LocalSummary.hash(id) + ".json") }
    public func load(repositoryID: String, description: String, modelVersion: String) throws -> LocalSummary? {
        let path = url(repositoryID)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let item = try JSONDecoder().decode(LocalSummary.self, from: Data(contentsOf: path))
        guard item.repositoryID == repositoryID, item.description == description,
              item.version == LocalSummary.promptVersion, item.modelVersion == modelVersion else { return nil }
        return item
    }
    public func save(_ item: LocalSummary) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(item).write(to: url(item.repositoryID), options: .atomic)
    }
}

public enum ReadmeError: Error, Equatable { case unavailable, tooLarge, invalidText, rateLimited }

/// README copies kept on this Mac, so repeated previews and explanations do not spend
/// GitHub's anonymous API limit (60 requests per hour, shared by everyone on a network).
public struct ReadmeCache {
    public struct Entry: Codable, Equatable {
        public let repositoryID: String
        public let etag: String?
        public let text: String
        public let fetchedAt: Date
        public init(repositoryID: String, etag: String?, text: String, fetchedAt: Date) {
            self.repositoryID = repositoryID; self.etag = etag; self.text = text; self.fetchedAt = fetchedAt
        }
    }
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private func url(_ id: String) -> URL { directory.appendingPathComponent(LocalSummary.hash(id.lowercased()) + ".json") }
    public func load(_ id: String) -> Entry? {
        guard let data = try? Data(contentsOf: url(id)), let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.repositoryID.lowercased() == id.lowercased() else { return nil }
        return entry
    }
    public func save(_ entry: Entry) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(entry).write(to: url(entry.repositoryID), options: .atomic)
    }
}

private final class ReadmeRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct ReadmeDocument {
    public let text: String
    public let sourceURL: URL
    public var hash: String { LocalSummary.hash(text) }
    // Keep the input within the on-device model's small context budget.
    public static func excerpt(_ text: String) -> String {
        var insideCode = false
        let withoutDecoration = text
            .replacingOccurrences(of: "(?is)<!--.*?-->|<picture\\b.*?</picture>|<img\\b[^>]*>|<source\\b[^>]*>", with: "", options: .regularExpression)
        let cleaned = withoutDecoration.components(separatedBy: .newlines).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") { insideCode.toggle(); return nil }
            guard !insideCode, !trimmed.hasPrefix("!["),
                  trimmed.range(of: "^<a\\b[^>]*>[^<]{0,50}</a>.*$", options: .regularExpression) == nil else { return nil }
            let plain = line.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;|&#160;", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return plain.isEmpty ? nil : plain
        }.joined(separator: "\n")
        var result = "", byteCount = 0
        for character in cleaned.prefix(4500) {
            let count = String(character).utf8.count
            guard byteCount + count <= 6000 else { break }
            result.append(character); byteCount += count
        }
        return result
    }
}

public struct ReadmeReader {
    /// Markdown source for on-device explanations; GitHub-rendered HTML for the preview.
    /// GitHub sanitizes the HTML (no scripts) and proxies external images.
    public enum Format: Sendable { case markdown, html }
    public let cache: ReadmeCache?
    public let format: Format
    public init(cache: ReadmeCache? = nil, format: Format = .markdown) { self.cache = cache; self.format = format }

    /// Decide what to do with a response, given any cached copy. Separated for testing.
    public enum Outcome: Equatable { case download, useCached, fail(ReadmeError) }
    public static func outcome(status: Int, remaining: String?, hasCached: Bool) -> Outcome {
        switch status {
        case 200: return .download
        case 304: return hasCached ? .useCached : .fail(.unavailable)
        case 403 where remaining == "0", 429:
            // A stale copy is better than nothing while the network's limit resets.
            return hasCached ? .useCached : .fail(.rateLimited)
        default: return .fail(.unavailable)
        }
    }

    /// Rendered HTML with GitHub's short-lived signed image links (user uploads in READMEs).
    public static func hasExpiringImages(_ html: String) -> Bool { html.contains("private-user-images.githubusercontent.com") }

    /// The API address of the main README, or of one file when `path` is given. Path segments are percent-encoded;
    /// `..` and empty paths are refused.
    public static func url(_ repository: String, path: String?) -> URL? {
        guard let path else { return URL(string: "https://api.github.com/repos/\(repository)/readme") }
        let segments = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !segments.isEmpty, !segments.contains(where: { $0.isEmpty || $0 == "." || $0 == ".." }) else { return nil }
        var allowed = CharacterSet.urlPathAllowed; allowed.remove(charactersIn: "/?#;")
        let encoded = segments.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowed) }
        return URL(string: "https://api.github.com/repos/\(repository)/contents/" + encoded.joined(separator: "/"))
    }

    /// - Parameter maxAge: reuse a cached copy younger than this without any request.
    ///   Older copies are revalidated with ETag, so an unchanged README is not downloaded again.
    /// - Parameter path: another file in the repository, such as a translated README; nil reads the main README.
    public func load(_ repository: Repository, path: String? = nil, maxAge: TimeInterval = 0) async throws -> ReadmeDocument {
        guard repository.githubURL != nil, let url = Self.url(repository.fullName, path: path) else { throw ReadmeError.unavailable }
        let key = path.map { repository.fullName + ":" + $0 } ?? repository.fullName
        // GitHub signs uploaded-image links in rendered HTML for only a few minutes, so such a copy cannot be
        // reused or revalidated (a 304 would bring back expired links); fetch it fresh instead.
        let cached = cache?.load(key).flatMap { format == .html && Self.hasExpiringImages($0.text) ? nil : $0 }
        if let cached, Date().timeIntervalSince(cached.fetchedAt) < maxAge { return ReadmeDocument(text: cached.text, sourceURL: url) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: ReadmeRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue(format == .html ? "application/vnd.github.html+json" : "application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        request.setValue("GitMorning", forHTTPHeaderField: "User-Agent")
        if let etag = cached?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw ReadmeError.unavailable }
        switch Self.outcome(status: http.statusCode, remaining: http.value(forHTTPHeaderField: "x-ratelimit-remaining"), hasCached: cached != nil) {
        case .download: break
        case .useCached:
            guard let cached else { throw ReadmeError.unavailable }
            if http.statusCode == 304 { cache?.save(.init(repositoryID: key, etag: cached.etag, text: cached.text, fetchedAt: Date())) }
            return ReadmeDocument(text: cached.text, sourceURL: url)
        case .fail(let error): throw error
        }
        guard response.expectedContentLength <= 2_000_000 else { throw ReadmeError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 2_000_000 else { throw ReadmeError.tooLarge }
            data.append(byte)
        }
        guard let text = String(data: data, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadmeError.invalidText }
        cache?.save(.init(repositoryID: key, etag: http.value(forHTTPHeaderField: "ETag"), text: text, fetchedAt: Date()))
        // The API finds README regardless of filename/casing; link to its canonical API resource.
        return ReadmeDocument(text: text, sourceURL: url)
    }
}
