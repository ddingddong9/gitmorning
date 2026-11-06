import Foundation

// Standalone checks for the daily rank history (no network).
@main
struct HistoryChecks {
    static func main() throws {
        func day(_ date: String, _ ranks: [String: Int]) -> [String: Any] { ["date": date, "collectedAt": date + "T08:00:00+00:00", "ranks": ranks] }
        func history(_ days: [[String: Any]], language: String = "all") throws -> Data {
            try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "period": "daily", "languageFilter": language,
                                                        "updatedAt": "2026-11-06T08:00:00+00:00", "days": days])
        }
        let data = try history([day("2026-11-02", ["a/one": 4]), day("2026-11-04", ["a/one": 3, "b/two": 9]),
                                day("2026-11-05", ["a/one": 2, "b/two": 5]), day("2026-11-06", ["a/one": 1, "b/two": 7, "c/new": 3])])
        let h = try TrendHistory.decode(data, language: "all")
        precondition(h.streak("a/one") == 3, "a missing day (11-03) ends the run")
        precondition(h.streak("b/two") == 3 && h.streak("c/new") == 1 && h.streak("gone/x") == 0)
        precondition(h.since("a/one") == "2026-11-04" && h.since("gone/x") == nil)
        let recent = h.recent("a/one", count: 5)
        precondition(recent.map(\.date) == ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"])
        precondition(recent.map(\.rank) == [4, nil, 3, 2, 1])
        precondition(h.matches(collectedAt: "2026-11-06T22:00:00Z") && h.matches(collectedAt: "2026-11-07T05:00:00Z"))
        precondition(!h.matches(collectedAt: "2026-11-09T05:00:00Z") && !h.matches(collectedAt: "2026-11-05T05:00:00Z"))
        precondition(TrendHistory.filename(language: "Python") == "history-daily-python.json")
        // Rejected: other list, unsorted days, bad ranks, unknown version.
        for (bad, language) in [(try history([day("2026-11-06", ["a/one": 1])], language: "Go"), "all"),
                                (try history([day("2026-11-06", ["a/one": 1]), day("2026-11-05", ["a/one": 1])]), "all"),
                                (try history([day("2026-11-06", ["a/one": 0])]), "all"),
                                (try history([day("not-a-day", ["a/one": 1])]), "all")] {
            var rejected = false
            do { _ = try TrendHistory.decode(bad, language: language) } catch { rejected = true }
            precondition(rejected)
        }
        print("PASS: rank history — streaks across missing days, since, recent ranks, same-day match, invalid files rejected")
    }
}
