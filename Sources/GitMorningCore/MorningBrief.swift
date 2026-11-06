import Foundation

/// A once-a-day digest of the daily Trending list: what is new or rising since
/// the previous day's brief. Regenerating on the same day keeps the same
/// comparison base, so a manual refresh never turns "since yesterday" into
/// "since ten minutes ago".
public struct MorningBrief: Codable, Equatable {
    public enum Change: Codable, Equatable {
        case new, rising(Int), unchanged
    }
    public struct Item: Codable, Equatable, Identifiable {
        public let id: String
        public let rank: Int
        public let change: Change
        public let description: String
        public let language: String?
        public let stars: Int?
        public let periodStars: Int?
        /// The language or keyword from the user's interests that this project matched.
        public var interest: String? = nil
    }

    public static let itemLimit = 10

    public var version = 1
    /// Local calendar day, yyyy-MM-dd.
    public let day: String
    public let generatedAt: Date
    public let collectedAt: String
    /// The list this brief compares against; nil for the very first brief.
    public let previous: VisitSnapshot?
    /// The list this brief was built from; tomorrow's brief compares against it.
    public let current: VisitSnapshot
    public internal(set) var items: [Item]
    public let newCount: Int
    public let risingCount: Int
    /// `Interests.signature` this brief was ordered with; nil before interests existed.
    public var interestSignature: String? = nil

    public var isFirst: Bool { previous == nil }
    public var hasNews: Bool { newCount + risingCount > 0 }

    /// The same brief with items re-marked and re-ordered for changed interests (no new list is fetched).
    public func reordered(by interests: Interests) -> MorningBrief {
        var copy = self
        let marked = items.map { item -> Item in
            var next = item
            next.interest = interests.match(language: item.language, texts: [item.id, item.description])
            return next
        }
        copy.items = marked.filter { $0.interest != nil } + marked.filter { $0.interest == nil }
        copy.interestSignature = interests.signature
        return copy
    }

    /// Projects matching `interests` come first (each group in Trending order); the brief keeps `itemLimit` items.
    public static func build(from snapshot: TrendSnapshot, day: String, now: Date, earlier: MorningBrief?, hidden: Set<String> = [],
                             interests: Interests = Interests()) -> MorningBrief {
        let previous = earlier.flatMap { $0.day == day ? $0.previous : $0.current }
        var candidates: [Item] = [], newCount = 0, risingCount = 0
        for repo in snapshot.repositories where !hidden.contains(repo.id) {
            let change: Change
            switch previous?.change(for: repo.id, currentRank: repo.rank) {
            case .new?: change = .new; newCount += 1
            case .moved(let delta)? where delta > 0: change = .rising(delta); risingCount += 1
            default: change = .unchanged
            }
            // The first brief has nothing to compare with, so it lists the top projects.
            guard previous == nil || change != .unchanged else { continue }
            let description = repo.description.isEmpty ? (Repository.excerpt(repo.readmeExcerpt) ?? "") : repo.description
            let interest = interests.match(language: repo.language, texts: [repo.id, repo.description, repo.readmeExcerpt ?? ""])
            candidates.append(Item(id: repo.id, rank: repo.rank, change: change, description: description,
                                   language: repo.language, stars: repo.stars, periodStars: repo.periodStars, interest: interest))
        }
        let items = Array((candidates.filter { $0.interest != nil } + candidates.filter { $0.interest == nil }).prefix(itemLimit))
        return MorningBrief(day: day, generatedAt: now, collectedAt: snapshot.collectedAt, previous: previous,
                            current: VisitSnapshot(collectedAt: snapshot.collectedAt, ids: snapshot.repositories.map(\.id)),
                            items: items, newCount: newCount, risingCount: risingCount, interestSignature: interests.signature)
    }
}

public enum MorningSchedule {
    public static let defaultMinute = 8 * 60

    public static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Due once per local day, at or after the chosen time, until a brief for that day exists.
    public static func isDue(now: Date, minuteOfDay: Int, lastDay: String?, calendar: Calendar = .current) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minute >= minuteOfDay && lastDay != day(now, calendar: calendar)
    }

    /// The next moment the brief becomes due, used to sleep until then.
    public static func nextDue(after now: Date, minuteOfDay: Int, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: now)
        let today = calendar.date(byAdding: .minute, value: minuteOfDay, to: start) ?? now
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
    }
}

public struct MorningBriefStorage {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> MorningBrief? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let value = try JSONDecoder().decode(MorningBrief.self, from: Data(contentsOf: url))
        guard value.version == 1 else { throw SnapshotError.unsupportedVersion }
        return value
    }
    public func save(_ value: MorningBrief) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
