import Foundation

/// A project's latest stable release, read from its public `releases.atom` feed on github.com
/// (no API request, so it does not use the anonymous API limit).
public struct ReleaseInfo: Codable, Equatable, Sendable {
    public let tag: String
    public let title: String
    public let url: String
    public let updated: String
}

public enum ReleaseFeed {
    public static func url(for repository: String) -> URL? {
        guard repository.range(of: "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil,
              !repository.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }) else { return nil }
        return URL(string: "https://github.com/\(repository)/releases.atom")
    }

    /// Nightly, preview, and pre-release tags change often; they never trigger an alert.
    static func isStable(_ tag: String) -> Bool {
        let lower = tag.lowercased()
        guard lower.rangeOfCharacter(from: .decimalDigits) != nil else { return false }  // "tip", "nightly", "latest"
        return lower.range(of: "(nightly|canary|alpha|beta|preview|snapshot|dev|edge|insiders|(^|[^a-z])rc[0-9.]*($|[^a-z])|(^|[^a-z])pre($|[^a-z]))",
                           options: .regularExpression) == nil
    }

    /// The newest stable release in an Atom feed, or nil when there is none.
    public static func latest(atom: Data, repository: String) -> ReleaseInfo? {
        let parser = AtomEntries()
        let xml = XMLParser(data: atom)
        xml.delegate = parser
        xml.shouldResolveExternalEntities = false
        guard xml.parse() else { return nil }
        let prefix = "https://github.com/\(repository)/releases/tag/".lowercased()
        for entry in parser.entries {
            guard entry.link.lowercased().hasPrefix(prefix) else { continue }
            let encoded = String(entry.link.dropFirst(prefix.count))
            let tag = encoded.removingPercentEncoding ?? encoded
            guard !tag.isEmpty, isStable(tag) else { continue }
            return ReleaseInfo(tag: tag, title: entry.title.trimmingCharacters(in: .whitespacesAndNewlines), url: entry.link, updated: entry.updated)
        }
        return nil
    }
}

private final class AtomEntries: NSObject, XMLParserDelegate {
    struct Entry { var title = "", link = "", updated = "" }
    private(set) var entries: [Entry] = []
    private var current: Entry?
    private var text = ""

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        text = ""
        if name == "entry" { current = Entry() }
        if name == "link", current != nil, attributes["rel"] ?? "alternate" == "alternate", let href = attributes["href"] { current?.link = href }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        guard current != nil else { return }
        switch name {
        case "title": current?.title = text
        case "updated": current?.updated = text
        case "entry": if let current { entries.append(current) }; current = nil
        default: break
        }
    }
}

/// What GitMorning knows about saved projects' releases: the latest stable release found,
/// and the release the user has already seen. A project's first check only records a baseline.
public struct ReleaseState: Codable, Equatable, Sendable {
    public var version = 1
    public var latest: [String: ReleaseInfo] = [:]
    public var seen: [String: String] = [:]
    public var checked: [String: Date] = [:]
    public init() {}

    /// Records a check. Returns the release when it is new since the last one the user saw.
    @discardableResult
    public mutating func record(_ id: String, release: ReleaseInfo?, at date: Date) -> ReleaseInfo? {
        checked[id] = date
        guard let release else { latest[id] = nil; return nil }  // no stable release (or it was removed)
        latest[id] = release
        guard let known = seen[id] else { seen[id] = release.tag; return nil }  // baseline, no alert
        return known == release.tag ? nil : release
    }

    /// The latest release when the user has not seen it yet.
    public func unseen(_ id: String) -> ReleaseInfo? {
        guard let release = latest[id], let known = seen[id], known != release.tag else { return nil }
        return release
    }

    public mutating func markSeen(_ id: String) {
        if let release = latest[id] { seen[id] = release.tag }
    }

    /// Saved projects to check now: never checked or checked more than `interval` ago, oldest first, at most `limit`.
    public func due(_ ids: [String], now: Date, interval: TimeInterval = 12 * 3600, limit: Int = 60) -> [String] {
        Array(ids.filter { checked[$0].map { now.timeIntervalSince($0) >= interval } ?? true }
            .sorted { (checked[$0] ?? .distantPast) < (checked[$1] ?? .distantPast) }
            .prefix(limit))
    }

    /// Forgets projects that are no longer saved.
    public mutating func keep(only ids: Set<String>) {
        latest = latest.filter { ids.contains($0.key) }
        seen = seen.filter { ids.contains($0.key) }
        checked = checked.filter { ids.contains($0.key) }
    }
}

public struct ReleaseStateStorage {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load() -> ReleaseState {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(ReleaseState.self, from: $0) } ?? ReleaseState()
    }
    public func save(_ state: ReleaseState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: url, options: .atomic)
    }
}
