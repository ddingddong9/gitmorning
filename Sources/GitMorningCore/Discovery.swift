import Foundation

public enum ProjectStage: String, Codable, CaseIterable, Identifiable {
    case later = "Try later", testing = "Testing", using = "In use"
    public var id: String { rawValue }
}
public struct ProjectReading: Codable, Equatable {
    public var read = false
    public var hidden = false
    public var note = ""
    public var stage: ProjectStage = .later
    public init() {}
}
public struct VisitSnapshot: Codable, Equatable {
    public let collectedAt: String
    public let ids: [String]
    public init(collectedAt: String, ids: [String]) { self.collectedAt = collectedAt; self.ids = ids }
    public func change(for id: String, currentRank: Int) -> RankChange {
        guard let previous = ids.firstIndex(of: id) else { return .new }
        return .moved(previous + 1 - currentRank)
    }
}
public enum RankChange: Equatable { case new, moved(Int) }
public struct DiscoveryCatalog: Codable {
    public var version = 1
    public var projects: [String: ProjectReading] = [:]
    public var visits: [String: VisitSnapshot] = [:]
    public init() {}
}
public struct DiscoveryStorage {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() throws -> DiscoveryCatalog {
        guard FileManager.default.fileExists(atPath: url.path) else { return DiscoveryCatalog() }
        let value = try JSONDecoder().decode(DiscoveryCatalog.self, from: Data(contentsOf: url))
        guard value.version == 1 else { throw SnapshotError.unsupportedVersion }
        return value
    }
    public func save(_ value: DiscoveryCatalog) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
