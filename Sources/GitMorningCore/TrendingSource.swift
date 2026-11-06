import Foundation

/// Where lists come from, with no setup: the shared hourly feed on GitHub Pages first,
/// GitHub Trending directly when the feed is missing or stale. A custom HTTPS address
/// in Settings replaces both and has no fallback, because the user chose it.
public enum TrendingSource {
    public static let sharedFeed = "https://ddingddong9.github.io/gitmorning/v1"
    /// The feed is scheduled hourly, but GitHub runs scheduled workflows of small repositories only every
    /// few hours (5–8 h observed). Older than this means the collector stopped or fell far behind.
    public static let maxFeedAge: TimeInterval = 8 * 3600

    public enum Origin: String, Equatable { case sharedFeed, customFeed, github, staleSharedFeed }

    public static func isFresh(_ collectedAt: Date?, now: Date = Date()) -> Bool {
        guard let collectedAt else { return false }
        return now.timeIntervalSince(collectedAt) <= maxFeedAge
    }

    public static func load(_ key: SnapshotKey, customAddress: String = "",
                            feed: @Sendable (SnapshotKey, FeedEndpoint) async throws -> Data = { try await SnapshotHTTPReader().load($0, endpoint: $1) },
                            github: @Sendable (SnapshotKey) async throws -> Data = { try await TrendingReader().load($0) },
                            now: Date = Date()) async throws -> (data: Data, origin: Origin) {
        let custom = customAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty { return (try await feed(key, FeedEndpoint(custom)), .customFeed) }
        var stale: Data?
        if let data = try? await feed(key, FeedEndpoint(sharedFeed)) {
            if isFresh(try? key.decode(data).collectedDate, now: now) { return (data, .sharedFeed) }
            stale = data
        }
        try Task.checkCancellation()
        do { return (try await github(key), .github) }
        catch {
            // GitHub unreachable: an old shared list still beats an error.
            if let stale, !(error is CancellationError) { return (stale, .staleSharedFeed) }
            throw error
        }
    }
}
