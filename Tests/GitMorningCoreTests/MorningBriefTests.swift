import Foundation
import Testing
@testable import GitMorningCore

struct MorningBriefTests {
    private let now = Date(timeIntervalSince1970: 1_793_746_800) // 2026-11-04 08:00 KST

    @Test func firstBriefListsTopProjectsWithoutChangeClaims() throws {
        let brief = try firstBrief()
        #expect(brief.isFirst)
        #expect(brief.items.map(\.id) == ["a/one", "b/two", "c/three"])
        #expect(brief.items.allSatisfy { $0.change == .unchanged })
        #expect(!brief.hasNews)
    }

    @Test func nextBriefIncludesOnlyVisibleNewAndRisingProjectsInRankOrder() throws {
        let first = try firstBrief()
        let brief = try nextBrief()
        #expect(brief.previous == first.current)
        #expect(brief.items.map(\.id) == ["d/four", "c/three"])
        #expect(brief.items.map(\.change) == [.new, .rising(1)])
        #expect(brief.newCount == 1)
        #expect(brief.risingCount == 1)
        #expect(brief.hasNews)
    }

    @Test func sameDayRefreshKeepsPreviousDaysComparisonBase() throws {
        let first = try firstBrief()
        let brief = try nextBrief()
        let today = try snapshot(["d/four", "c/three", "a/one", "e/five", "b/two"])
        let refreshed = MorningBrief.build(from: today, day: "2026-11-04", now: now, earlier: brief)
        #expect(refreshed.previous == first.current)
        #expect(refreshed.newCount == 2)
    }

    @Test func itemLimitDoesNotCapChangeCounts() throws {
        let brief = try nextBrief()
        let many = try snapshot((1...15).map { "n/r\($0)" })
        let capped = MorningBrief.build(from: many, day: "2026-11-05", now: now, earlier: brief)
        #expect(capped.items.count == MorningBrief.itemLimit)
        #expect(capped.newCount == 15)
    }

    @Test func scheduleUsesLocalCalendarDay() {
        #expect(MorningSchedule.day(now, calendar: calendar) == "2026-11-04")
    }

    @Test func scheduleIsDueOncePerDayAtOrAfterChosenMinute() {
        #expect(MorningSchedule.isDue(now: now, minuteOfDay: 480, lastDay: "2026-11-03", calendar: calendar))
        #expect(!MorningSchedule.isDue(now: now, minuteOfDay: 480, lastDay: "2026-11-04", calendar: calendar))
        #expect(!MorningSchedule.isDue(now: now, minuteOfDay: 481, lastDay: nil, calendar: calendar))
    }

    @Test func nextDueUsesTomorrowAtChosenMinuteOrLaterToday() {
        let next = MorningSchedule.nextDue(after: now, minuteOfDay: 480, calendar: calendar)
        #expect(next.timeIntervalSince(now) == 86_400)
        #expect(MorningSchedule.nextDue(after: now, minuteOfDay: 540, calendar: calendar).timeIntervalSince(now) == 3_600)
    }

    @Test func storageLoadsMissingFileRoundTripsBriefAndRejectsCorruptData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = MorningBriefStorage(url: directory.appendingPathComponent("brief-v1.json"))
        #expect(try storage.load() == nil)

        let brief = try nextBrief()
        try storage.save(brief)
        #expect(try storage.load() == brief)

        try Data("broken".utf8).write(to: storage.url)
        #expect(throws: (any Error).self) {
            _ = try storage.load()
        }
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }

    private func firstBrief() throws -> MorningBrief {
        MorningBrief.build(from: try snapshot(["a/one", "b/two", "c/three"]), day: "2026-11-03", now: now, earlier: nil)
    }

    private func nextBrief() throws -> MorningBrief {
        let today = try snapshot(["d/four", "c/three", "a/one", "e/five", "b/two"])
        return MorningBrief.build(from: today, day: "2026-11-04", now: now, earlier: try firstBrief(), hidden: ["e/five"])
    }

    private func snapshot(_ ids: [String], collectedAt: String = "2026-11-04T00:00:00Z") throws -> TrendSnapshot {
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
}
