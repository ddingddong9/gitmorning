import Foundation

@main struct DiscoveryChecks {
    static func main() throws {
        let key = try SnapshotKey(period: "daily", language: "all")
        let row = """
        <article class="Box-row"><h2><a href="/owner/tool"><span>owner /</span> tool</a></h2>
        <p>Read <strong>this</strong> &amp; learn &#xD55C;&#44544;.</p>
        <span itemprop="programmingLanguage">Swift</span>
        <a href="/owner/tool/stargazers"><svg></svg>12,345</a>
        <span>1,234 stars today</span><form><p>Ignore this</p></form></article>
        """
        let data = try TrendingHTML.snapshot("<template>" + row + "</template>" + row, key: key)
        let snapshot = try key.decode(data)
        precondition(snapshot.repositories.count == 1)
        let repo = snapshot.repositories[0]
        precondition(repo.id == "owner/tool" && repo.description == "Read this & learn 한글.")
        precondition(repo.stars == 12345 && repo.periodStars == 1234 && repo.language == "Swift")
        let minimal = "<article class='Box-row'><h2><a href='/another/repo'>repo</a></h2></article>"
        let unknown = try key.decode(TrendingHTML.snapshot(minimal, key: key)).repositories[0]
        precondition(unknown.stars == nil && unknown.periodStars == nil && unknown.description.isEmpty)
        for bad in [row + row, "<article class='Box-row'><h2>bad</h2></article>", "<html>rate limited</html>", "<article hidden class='Box-row'>" + minimal + "</article>"] {
            var rejected = false
            do { _ = try TrendingHTML.snapshot(bad, key: key) } catch { rejected = true }
            precondition(rejected)
        }
        let previous = VisitSnapshot(collectedAt: "2026-11-01T00:00:00Z", ids: ["a/one", "b/two"])
        precondition(previous.change(for: "c/new", currentRank: 1) == .new)
        precondition(previous.change(for: "b/two", currentRank: 1) == .moved(1))
        precondition(previous.change(for: "a/one", currentRank: 2) == .moved(-1))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = DiscoveryStorage(url: directory.appendingPathComponent("discovery.json"))
        var catalog = try storage.load()
        precondition(catalog.projects.isEmpty)
        var reading = ProjectReading(); reading.read = true; reading.hidden = true; reading.note = "사용해 볼 도구\nSecond line"; reading.stage = .testing
        catalog.projects[repo.id] = reading; catalog.visits[key.filename] = previous
        try storage.save(catalog)
        let restored = try storage.load()
        precondition(restored.projects[repo.id] == reading && restored.visits[key.filename] == previous)
        let weekly = try SnapshotKey(period: "weekly", language: "Swift")
        precondition(restored.visits[weekly.filename] == nil)
        try Data("broken".utf8).write(to: storage.url)
        var rejected = false
        do { _ = try storage.load() } catch { rejected = true }
        precondition(rejected)
        let preserved = try String(contentsOf: storage.url, encoding: .utf8)
        precondition(preserved == "broken")
        print("PASS: Trending structure, text order/entities, optional metrics, duplicate/invalid/hidden rejection; rank deltas, isolated lists, durable notes/read/hidden/stage, corrupt store preserved")
    }
}
