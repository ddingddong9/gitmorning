import Foundation

/// The shared feed's daily rank history for one daily list (`history-daily-<language>.json`):
/// each repository's rank for each of the last days (UTC dates), oldest first.
public struct TrendHistory: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public let date: String
        public let collectedAt: String
        public let ranks: [String: Int]
    }

    public let schemaVersion: Int
    public let period: String
    public let languageFilter: String
    public let updatedAt: String
    public let days: [Day]

    public static func filename(language: String) -> String { "history-daily-\(language.lowercased()).json" }

    private static let dayFormat: Date.ISO8601FormatStyle = .iso8601.year().month().day()
    static func date(_ day: String) -> Date? { try? dayFormat.parse(day) }

    /// Decodes and checks a history file for `language` ("all", "Python", …). Unknown versions,
    /// other lists, unsorted or invalid days, and non-positive ranks are rejected.
    public static func decode(_ data: Data, language: String) throws -> TrendHistory {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1 else { throw SnapshotError.unsupportedVersion }
        guard value.period == "daily", value.languageFilter == language, value.days.count <= 31,
              SnapshotDate.parse(value.updatedAt) != nil else { throw SnapshotError.invalidSnapshot }
        var previous: Date?
        for day in value.days {
            guard let date = date(day.date), previous.map({ date > $0 }) ?? true,
                  day.ranks.values.allSatisfy({ $0 > 0 }) else { throw SnapshotError.invalidSnapshot }
            previous = date
        }
        return value
    }

    /// Whether this history describes the same day as a list collected at `collectedAt`
    /// (its newest day is that UTC date or the day before), so streaks are not shown against an old history.
    public func matches(collectedAt: String) -> Bool {
        guard let last = days.last.flatMap({ Self.date($0.date) }), let collected = SnapshotDate.parse(collectedAt) else { return false }
        let gap = collected.timeIntervalSince(last)
        return gap >= 0 && gap < 2 * 86_400
    }

    /// Consecutive days, ending with the newest day, on which `id` was on the list. 0 if it is not on the newest day.
    public func streak(_ id: String) -> Int {
        var count = 0
        var expected: Date?
        for day in days.reversed() {
            guard day.ranks[id] != nil, let date = Self.date(day.date) else { break }
            if let expected, date != expected { break }  // a missing day breaks the run
            count += 1
            expected = date.addingTimeInterval(-86_400)
        }
        return count
    }

    /// The first day of the current streak, as `yyyy-MM-dd`.
    public func since(_ id: String) -> String? {
        let count = streak(id)
        return count > 0 ? days[days.count - count].date : nil
    }

    /// A short date label such as "Nov 6" or "11월 6일" for a `yyyy-MM-dd` day.
    public static func label(_ day: String, locale: Locale) -> String {
        guard let date = date(day) else { return day }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).month(.abbreviated).day().locale(locale)
        style.timeZone = TimeZone(identifier: "UTC")!
        return date.formatted(style)
    }

    /// Rank on each of the last `count` calendar days ending with the newest day (nil when not on the list or no data).
    public func recent(_ id: String, count: Int = 7) -> [(date: String, rank: Int?)] {
        guard let last = days.last.flatMap({ Self.date($0.date) }) else { return [] }
        let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
        return (0..<count).reversed().map { offset in
            let day = last.addingTimeInterval(-Double(offset) * 86_400).formatted(Self.dayFormat)
            return (day, byDate[day]?.ranks[id])
        }
    }
}
