import Foundation

@main struct SourceChecks {
    static func snapshot(collectedAt: String) throws -> Data {
        let payload: [String: Any] = ["schemaVersion": 1, "period": "daily", "languageFilter": "all",
                                      "sourceURL": "https://github.com/trending?since=daily", "collectedAt": collectedAt, "status": "complete",
                                      "repositories": [["id": "o/r", "owner": "o", "name": "r", "url": "https://github.com/o/r", "rank": 1,
                                                        "description": "", "language": NSNull(), "stars": NSNull(), "periodStars": NSNull(), "summaryStatus": "pending"]]]
        return try JSONSerialization.data(withJSONObject: payload)
    }
    struct Offline: Error {}

    static func main() async throws {
        let key = try SnapshotKey(period: "daily", language: "all")
        let now = ISO8601DateFormatter().date(from: "2026-11-04T03:00:00Z")!
        let fresh = try snapshot(collectedAt: "2026-11-04T02:07:00Z")
        let stale = try snapshot(collectedAt: "2026-11-03T18:07:00Z")
        let direct = try snapshot(collectedAt: "2026-11-04T03:00:00Z")
        let feedOK: @Sendable (SnapshotKey, FeedEndpoint) async throws -> Data = { _, endpoint in
            precondition(endpoint.baseURL.absoluteString == TrendingSource.sharedFeed); return fresh }
        let feedStale: @Sendable (SnapshotKey, FeedEndpoint) async throws -> Data = { _, _ in stale }
        let feedDown: @Sendable (SnapshotKey, FeedEndpoint) async throws -> Data = { _, _ in throw Offline() }
        let githubOK: @Sendable (SnapshotKey) async throws -> Data = { _ in direct }
        let githubDown: @Sendable (SnapshotKey) async throws -> Data = { _ in throw Offline() }

        // Fresh shared feed is used without touching GitHub.
        let noGitHub: @Sendable (SnapshotKey) async throws -> Data = { _ in preconditionFailure("GitHub must not be read") }
        do { let r = try await TrendingSource.load(key, feed: feedOK, github: noGitHub, now: now); precondition(r.origin == .sharedFeed) }
        // GitHub runs the hourly schedule every few hours, so a six-hour-old feed is still used.
        let sixHours = try snapshot(collectedAt: "2026-11-03T21:00:00Z")
        do { let r = try await TrendingSource.load(key, feed: { _, _ in sixHours }, github: noGitHub, now: now); precondition(r.origin == .sharedFeed) }
        // Stale (over eight hours) or missing feed falls back to GitHub.
        do { let r = try await TrendingSource.load(key, feed: feedStale, github: githubOK, now: now); precondition(r.origin == .github) }
        do { let r = try await TrendingSource.load(key, feed: feedDown, github: githubOK, now: now); precondition(r.origin == .github) }
        // GitHub down: a stale shared list beats an error; nothing at all is an error.
        do { let r = try await TrendingSource.load(key, feed: feedStale, github: githubDown, now: now); precondition(r.origin == .staleSharedFeed) }
        var failed = false
        do { _ = try await TrendingSource.load(key, feed: feedDown, github: githubDown, now: now) } catch { failed = true }
        precondition(failed)
        // A custom address is used alone, with no fallback.
        let custom: @Sendable (SnapshotKey, FeedEndpoint) async throws -> Data = { _, endpoint in
            precondition(endpoint.baseURL.absoluteString == "https://example.com/feed"); throw Offline() }
        failed = false
        do { _ = try await TrendingSource.load(key, customAddress: " https://example.com/feed ", feed: custom, github: githubOK, now: now) } catch { failed = true }
        precondition(failed)
        precondition(TrendingSource.isFresh(now.addingTimeInterval(-TrendingSource.maxFeedAge), now: now))
        precondition(!TrendingSource.isFresh(now.addingTimeInterval(-TrendingSource.maxFeedAge - 1), now: now) && !TrendingSource.isFresh(nil, now: now))
        print("PASS: fresh shared feed first, GitHub when stale or missing, stale list when GitHub is down, custom address alone")
    }
}
