import Foundation

@main struct ReadmeChecks {
    static func main() async throws {
        // Response handling: download, reuse on 304, fall back to a stale copy when rate limited.
        precondition(ReadmeReader.outcome(status: 200, remaining: "59", hasCached: false) == .download)
        precondition(ReadmeReader.outcome(status: 304, remaining: "58", hasCached: true) == .useCached)
        precondition(ReadmeReader.outcome(status: 304, remaining: "58", hasCached: false) == .fail(.unavailable))
        precondition(ReadmeReader.outcome(status: 403, remaining: "0", hasCached: true) == .useCached)
        precondition(ReadmeReader.outcome(status: 403, remaining: "0", hasCached: false) == .fail(.rateLimited))
        precondition(ReadmeReader.outcome(status: 429, remaining: nil, hasCached: false) == .fail(.rateLimited))
        precondition(ReadmeReader.outcome(status: 403, remaining: "12", hasCached: true) == .fail(.unavailable))
        precondition(ReadmeReader.outcome(status: 404, remaining: "50", hasCached: true) == .fail(.unavailable))

        // Cache: case-insensitive identity, round trip, and no cross-repository reuse.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ReadmeCache(directory: directory)
        precondition(cache.load("owner/tool") == nil)
        let entry = ReadmeCache.Entry(repositoryID: "Owner/Tool", etag: "\"abc\"", text: "# Tool", fetchedAt: Date())
        cache.save(entry)
        precondition(cache.load("owner/tool") == entry && cache.load("other/tool") == nil)
        try Data("broken".utf8).write(to: directory.appendingPathComponent(LocalSummary.hash("broken/repo") + ".json"))
        precondition(cache.load("broken/repo") == nil)

        // A fresh cached copy is returned without any network request.
        let repository = Repository(id: "Owner/Tool", owner: "Owner", language: "Swift", summary: "", introduction: "", features: [], usage: "", stars: nil, dailyGain: nil, weeklyGain: nil)
        let text = try await ReadmeReader(cache: cache).load(repository, maxAge: 3600).text
        precondition(text == "# Tool")
        print("PASS: README 200/304/rate-limit outcomes, stale copy on limit, cache identity and corruption, fresh copy without request")
    }
}
