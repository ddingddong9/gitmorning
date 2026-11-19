import Foundation
import Testing
@testable import GitMorningCore

struct TrendHistoryTests {
    @Test func streaksEndAtMissingDaysAndAbsentProjects() throws {
        let history = try sampleHistory()
        #expect(history.streak("a/one") == 3, "A missing day (11-03) ends the run")
        #expect(history.streak("b/two") == 3)
        #expect(history.streak("c/new") == 1)
        #expect(history.streak("gone/x") == 0)
    }

    @Test func sinceReturnsStartOfCurrentStreak() throws {
        let history = try sampleHistory()
        #expect(history.since("a/one") == "2026-11-04")
        #expect(history.since("gone/x") == nil)
    }

    @Test func recentRanksIncludeMissingCalendarDays() throws {
        let recent = try sampleHistory().recent("a/one", count: 5)
        #expect(recent.map(\.date) == ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"])
        #expect(recent.map(\.rank) == [4, nil, 3, 2, 1])
    }

    @Test func matchesOnlySnapshotsOnLatestHistoryDayOrFollowingDay() throws {
        let history = try sampleHistory()
        #expect(history.matches(collectedAt: "2026-11-06T22:00:00Z"))
        #expect(history.matches(collectedAt: "2026-11-07T05:00:00Z"))
        #expect(!history.matches(collectedAt: "2026-11-09T05:00:00Z"))
        #expect(!history.matches(collectedAt: "2026-11-05T05:00:00Z"))
    }

    @Test func filenameUsesLowercaseLanguage() {
        #expect(TrendHistory.filename(language: "Python") == "history-daily-python.json")
    }

    @Test(arguments: InvalidHistory.allCases)
    func invalidHistoriesAreRejected(_ scenario: InvalidHistory) throws {
        let data: Data
        switch scenario {
        case .otherLanguage:
            data = try historyData([day("2026-11-06", ["a/one": 1])], language: "Go")
        case .unsortedDays:
            data = try historyData([day("2026-11-06", ["a/one": 1]), day("2026-11-05", ["a/one": 1])])
        case .nonPositiveRank:
            data = try historyData([day("2026-11-06", ["a/one": 0])])
        case .invalidDate:
            data = try historyData([day("not-a-day", ["a/one": 1])])
        }
        #expect(throws: (any Error).self) {
            _ = try TrendHistory.decode(data, language: "all")
        }
    }

    enum InvalidHistory: CaseIterable, Sendable {
        case otherLanguage, unsortedDays, nonPositiveRank, invalidDate
    }

    private func sampleHistory() throws -> TrendHistory {
        let data = try historyData([day("2026-11-02", ["a/one": 4]), day("2026-11-04", ["a/one": 3, "b/two": 9]),
                                    day("2026-11-05", ["a/one": 2, "b/two": 5]), day("2026-11-06", ["a/one": 1, "b/two": 7, "c/new": 3])])
        return try TrendHistory.decode(data, language: "all")
    }

    private func day(_ date: String, _ ranks: [String: Int]) -> [String: Any] {
        ["date": date, "collectedAt": date + "T08:00:00+00:00", "ranks": ranks]
    }

    private func historyData(_ days: [[String: Any]], language: String = "all") throws -> Data {
        try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "period": "daily", "languageFilter": language,
                                                  "updatedAt": "2026-11-06T08:00:00+00:00", "days": days])
    }
}
