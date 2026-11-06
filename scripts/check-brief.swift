import Foundation

@main struct BriefChecks {
    static func snapshot(_ ids: [String], collectedAt: String = "2026-11-04T00:00:00Z") throws -> TrendSnapshot {
        let rows = ids.enumerated().map { index, id -> [String: Any] in
            let parts = id.split(separator: "/").map(String.init)
            return ["id": id, "owner": parts[0], "name": parts[1], "url": "https://github.com/" + id, "rank": index + 1,
                    "description": "About " + parts[1], "language": "Swift", "stars": 100, "periodStars": 10, "summaryStatus": "pending"]
        }
        let payload: [String: Any] = ["schemaVersion": 1, "period": "daily", "languageFilter": "all",
                                      "sourceURL": "https://github.com/trending?since=daily", "collectedAt": collectedAt,
                                      "status": "complete", "repositories": rows]
        return try TrendSnapshot.decode(JSONSerialization.data(withJSONObject: payload))
    }

    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = Date(timeIntervalSince1970: 1_793_746_800) // 2026-11-04 08:00 KST

        // First brief: no comparison, lists the top projects without change claims.
        let first = MorningBrief.build(from: try snapshot(["a/one", "b/two", "c/three"]), day: "2026-11-03", now: now, earlier: nil)
        precondition(first.isFirst && first.items.map(\.id) == ["a/one", "b/two", "c/three"])
        precondition(first.items.allSatisfy { $0.change == .unchanged } && !first.hasNews)

        // Next day: new and rising projects only, in current rank order; hidden ones excluded.
        let today = try snapshot(["d/four", "c/three", "a/one", "e/five", "b/two"])
        let brief = MorningBrief.build(from: today, day: "2026-11-04", now: now, earlier: first, hidden: ["e/five"])
        precondition(brief.previous == first.current)
        precondition(brief.items.map(\.id) == ["d/four", "c/three"], "\(brief.items.map(\.id))")
        precondition(brief.items[0].change == .new && brief.items[1].change == .rising(1))
        precondition(brief.newCount == 1 && brief.risingCount == 1 && brief.hasNews)

        // Same-day refresh keeps yesterday as the base instead of comparing with itself.
        let refreshed = MorningBrief.build(from: today, day: "2026-11-04", now: now, earlier: brief)
        precondition(refreshed.previous == first.current && refreshed.newCount == 2)

        // Item list is capped; counts still cover every change.
        let many = try snapshot((1...15).map { "n/r\($0)" })
        let capped = MorningBrief.build(from: many, day: "2026-11-05", now: now, earlier: brief)
        precondition(capped.items.count == MorningBrief.itemLimit && capped.newCount == 15)

        // Schedule: due once per day at or after the chosen minute.
        precondition(MorningSchedule.day(now, calendar: calendar) == "2026-11-04")
        precondition(MorningSchedule.isDue(now: now, minuteOfDay: 480, lastDay: "2026-11-03", calendar: calendar))
        precondition(!MorningSchedule.isDue(now: now, minuteOfDay: 480, lastDay: "2026-11-04", calendar: calendar))
        precondition(!MorningSchedule.isDue(now: now, minuteOfDay: 481, lastDay: nil, calendar: calendar))
        let next = MorningSchedule.nextDue(after: now, minuteOfDay: 480, calendar: calendar)
        precondition(next.timeIntervalSince(now) == 86_400)
        precondition(MorningSchedule.nextDue(after: now, minuteOfDay: 540, calendar: calendar).timeIntervalSince(now) == 3_600)

        // Storage round trip; a corrupt file is reported, not overwritten.
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MorningBriefStorage(url: directory.appendingPathComponent("brief-v1.json"))
        let empty = try storage.load()
        precondition(empty == nil)
        try storage.save(brief)
        let restored = try storage.load()
        precondition(restored == brief)
        try Data("broken".utf8).write(to: storage.url)
        var rejected = false
        do { _ = try storage.load() } catch { rejected = true }
        precondition(rejected)

        print("PASS: first brief, new/rising since yesterday, hidden excluded, same-day base kept, item cap, daily schedule, storage")
    }
}
