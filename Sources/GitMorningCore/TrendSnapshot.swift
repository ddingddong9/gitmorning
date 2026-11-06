import Foundation

/// Wire contract for generated snapshots. Unknown metrics remain optional.
public struct TrendSnapshot: Decodable {
    public let schemaVersion: Int
    public let period: String
    public let languageFilter: String
    public let sourceURL: String
    public let collectedAt: String
    public let status: String
    public let repositories: [TrendingRepository]
    public var collectedDate: Date? {
        SnapshotDate.parse(collectedAt)
    }

    public static func decode(_ data: Data) throws -> TrendSnapshot {
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.schemaVersion == 1 else { throw SnapshotError.unsupportedVersion }
        guard ["daily", "weekly"].contains(value.period), value.status == "complete", !value.repositories.isEmpty else { throw SnapshotError.invalidSnapshot }
        let languages = ["all": "", "Python": "python", "TypeScript": "typescript", "JavaScript": "javascript", "Swift": "swift", "Go": "go", "Rust": "rust"]
        guard let slug = languages[value.languageFilter] else { throw SnapshotError.invalidSnapshot }
        let source = "https://github.com/trending" + (slug.isEmpty ? "" : "/" + slug) + "?since=" + value.period
        guard value.sourceURL == source else { throw SnapshotError.invalidSource }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if formatter.date(from: value.collectedAt) == nil {
            formatter.formatOptions = [.withInternetDateTime]
            guard formatter.date(from: value.collectedAt) != nil else { throw SnapshotError.invalidSnapshot }
        }
        var ids = Set<String>()
        for (index, repo) in value.repositories.enumerated() {
            guard repo.rank == index + 1, repo.id == repo.owner + "/" + repo.name,
                  repo.id.range(of: "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil,
                  repo.url == "https://github.com/" + repo.id,
                  ids.insert(repo.id.lowercased()).inserted,
                  repo.stars.map({ $0 >= 0 }) ?? true,
                  repo.periodStars.map({ $0 >= 0 }) ?? true else { throw SnapshotError.invalidRepository }
        }
        return value
    }
}

public struct TrendingRepository: Decodable, Identifiable {
    public let id: String
    public let owner: String
    public let name: String
    public let url: String
    public let rank: Int
    public let description: String
    public let language: String?
    public let stars: Int?
    public let periodStars: Int?
    public let summaryStatus: String
    /// First descriptive paragraph of the README, added by the shared feed. Absent when read from GitHub directly.
    public let readmeExcerpt: String?
}

public enum SnapshotError: Error {
    case unsupportedVersion, invalidSnapshot, invalidSource, invalidRepository
}
