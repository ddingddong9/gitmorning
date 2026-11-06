import Foundation

// Standalone checks for saved-project release alerts (no network).
@main
struct ReleaseChecks {
    static func main() {
        func atom(_ entries: [(String, String)]) -> Data {
            let body = entries.map { tag, title in
                "<entry><id>x</id><updated>2026-11-05T10:00:00Z</updated><link rel=\"alternate\" type=\"text/html\" href=\"https://github.com/Owner/Tool/releases/tag/\(tag)\"/><title>\(title)</title><content type=\"html\">&lt;p&gt;notes&lt;/p&gt;</content></entry>"
            }.joined()
            return Data("<?xml version=\"1.0\"?><feed xmlns=\"http://www.w3.org/2005/Atom\"><title>Release notes</title>\(body)</feed>".utf8)
        }
        let feed = atom([("tip", "Nightly"), ("v2.0.0-rc.1", "RC"), ("v1.5.0-beta", "Beta"), ("v1.4.0", "Tool 1.4 &amp; more"), ("v1.3.0", "Old")])
        let latest = ReleaseFeed.latest(atom: feed, repository: "owner/tool")
        precondition(latest?.tag == "v1.4.0" && latest?.title == "Tool 1.4 & more" && latest?.url.hasSuffix("/tag/v1.4.0") == true, "\(String(describing: latest))")
        precondition(ReleaseFeed.latest(atom: atom([]), repository: "owner/tool") == nil)
        precondition(ReleaseFeed.latest(atom: Data("not xml".utf8), repository: "owner/tool") == nil)
        precondition(ReleaseFeed.latest(atom: atom([("v%E2%9C%93-1", "Encoded")]), repository: "owner/tool")?.tag == "v✓-1")
        for (tag, stable) in [("v1.2.3", true), ("2026.11.05", true), ("release-42", true), ("tip", false), ("nightly-2026", false),
                              ("v1.0.0-rc1", false), ("v1.0.0-alpha.2", false), ("v3-preview", false), ("v2.1-pre", false), ("v1.0.0-src", true)] {
            precondition(ReleaseFeed.isStable(tag) == stable, tag)
        }
        precondition(ReleaseFeed.url(for: "owner/tool")?.absoluteString == "https://github.com/owner/tool/releases.atom" && ReleaseFeed.url(for: "../x") == nil)

        let now = Date(timeIntervalSince1970: 1_793_800_000)
        func release(_ tag: String) -> ReleaseInfo { ReleaseInfo(tag: tag, title: tag, url: "u", updated: "d") }
        var state = ReleaseState()
        precondition(state.record("a/b", release: release("v1"), at: now) == nil, "first check is a baseline")
        precondition(state.unseen("a/b") == nil && state.record("a/b", release: release("v1"), at: now) == nil)
        precondition(state.record("a/b", release: release("v2"), at: now)?.tag == "v2" && state.unseen("a/b")?.tag == "v2")
        state.markSeen("a/b")
        precondition(state.unseen("a/b") == nil && state.record("a/b", release: release("v2"), at: now) == nil)
        precondition(state.record("c/d", release: nil, at: now) == nil && state.unseen("c/d") == nil)
        var removed = ReleaseState(); removed.record("x/y", release: release("v1"), at: now); removed.record("x/y", release: nil, at: now)
        precondition(removed.latest["x/y"] == nil && removed.unseen("x/y") == nil)
        let later = now.addingTimeInterval(13 * 3600)
        state.checked["e/f"] = now.addingTimeInterval(-20 * 3600)
        precondition(state.due(["a/b", "c/d", "e/f", "new/one"], now: now) == ["new/one", "e/f"])
        precondition(state.due(["a/b", "c/d", "e/f"], now: later) == ["e/f", "a/b", "c/d"] || state.due(["a/b", "c/d", "e/f"], now: later) == ["e/f", "c/d", "a/b"])
        state.keep(only: ["a/b"])
        precondition(state.latest.keys.sorted() == ["a/b"] && state.checked.keys.sorted() == ["a/b"])
        print("PASS: release alerts — stable tags from Atom (nightly, rc, beta skipped), baseline on first check, new, seen, due order, cleanup")
    }
}
