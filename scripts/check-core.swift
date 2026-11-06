import Foundation

// Standalone checks for Command Line Tools installations without XCTest.
@main
struct CoreChecks {
    static func main() throws {
        let source = Repository.samples
        let saved = [Bookmark(repositoryID: "docnest", savedAt: Date(timeIntervalSince1970: 1)), Bookmark(repositoryID: "flowline", savedAt: Date(timeIntervalSince1970: 2))]
        precondition(Catalog.filter(source, feed: .saved, language: "Python", query: " 문서 ", bookmarks: saved).map(\.id) == ["docnest"])
        precondition(Catalog.filter(source, feed: .saved, language: "Rust", query: "", bookmarks: saved).isEmpty)
        precondition(Catalog.filter(source, feed: .daily, language: nil, query: "OPENKIT", bookmarks: []).map(\.id) == ["docnest"])
        precondition(Catalog.filter(source, feed: .saved, language: nil, query: "", bookmarks: saved).map(\.id) == ["flowline", "docnest"])
        let reversed = Array(source.reversed())
        precondition(Catalog.filter(reversed, feed: .weekly, language: nil, query: "", bookmarks: []).map(\.id) == reversed.map(\.id))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = BookmarkStorage(url: directory.appendingPathComponent("nested/bookmarks.json"))
        let empty = try storage.load()
        precondition(empty.isEmpty)
        try storage.save(saved)
        let restored = try storage.load()
        precondition(restored == saved)
        try Data("broken".utf8).write(to: storage.url)
        var rejected = false
        do { _ = try storage.load() } catch { rejected = true }
        precondition(rejected)
        // README excerpts from the shared feed: a separate section, or the summary when GitHub has no description.
        let feedJSON = """
        {"schemaVersion":1,"period":"daily","languageFilter":"all","sourceURL":"https://github.com/trending?since=daily","collectedAt":"2026-11-04T00:00:00Z","status":"complete","repositories":[
        {"id":"a/one","owner":"a","name":"one","url":"https://github.com/a/one","rank":1,"description":"Short tool.","language":"Go","stars":1,"periodStars":1,"summaryStatus":"pending","readmeExcerpt":"One does a longer explanation of what it is."},
        {"id":"b/two","owner":"b","name":"two","url":"https://github.com/b/two","rank":2,"description":"","language":null,"stars":null,"periodStars":null,"summaryStatus":"pending","readmeExcerpt":" Two explains itself only in its README. "},
        {"id":"c/three","owner":"c","name":"three","url":"https://github.com/c/three","rank":3,"description":"","language":null,"stars":null,"periodStars":null,"summaryStatus":"pending"}]}
        """
        let feed = try TrendSnapshot.decode(Data(feedJSON.utf8))
        let repos = Repository.from(feed)
        precondition(repos[0].summary == "Short tool." && repos[0].readmeExcerpt == "One does a longer explanation of what it is." && repos[0].summaryFromReadme == nil)
        precondition(repos[0].readmeExcerptItem?.summary == repos[0].readmeExcerpt && repos[0].readmeExcerptItem?.id == "a/one")
        precondition(repos[1].summary == "Two explains itself only in its README." && repos[1].readmeExcerpt == nil && repos[1].summaryFromReadme == true)
        precondition(repos[2].summary == "No description provided." && repos[2].readmeExcerpt == nil)
        let brief = MorningBrief.build(from: feed, day: "2026-11-04", now: Date(), earlier: nil)
        precondition(brief.items.map(\.description) == ["Short tool.", "Two explains itself only in its README.", ""])
        // Saved projects from older versions, without the new fields, still decode.
        let old = try JSONEncoder().encode(Repository.samples[0])
        var object = try JSONSerialization.jsonObject(with: old) as! [String: Any]
        object.removeValue(forKey: "readmeExcerpt"); object.removeValue(forKey: "summaryFromReadme")
        let decodedOld = try JSONDecoder().decode(Repository.self, from: JSONSerialization.data(withJSONObject: object))
        precondition(decodedOld.readmeExcerpt == nil && decodedOld.summaryFromReadme == nil)
        print("PASS: 11 core checks — filtering, case-insensitive search, source order, bookmark order, persistence, corrupt-data rejection, README excerpts, brief fallback, older saved data")
    }
}
