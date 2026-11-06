import SwiftUI
import AppKit
import Observation
import GitMorningCore

@MainActor @Observable
final class AppState {
    var feed: Feed = .daily
    var query = ""
    var translatedSearchDescriptions: [String: String] = [:]
    var language = "All languages"
    var selectedID: String?
    var readingFilter = "All projects"
    private(set) var discovery = DiscoveryCatalog()
    private let discoveryStorage: DiscoveryStorage
    private var canSaveDiscovery = true
    private var baselines: [String: VisitSnapshot] = [:]
    private var visitedKeys = Set<String>()
    private(set) var bookmarks: [Bookmark] = []
    private(set) var snapshot: TrendSnapshot?
    private(set) var savedRepositories: [String: Repository] = [:]
    private(set) var isLoading = false
    private(set) var status = "Bundled snapshot"
    var message: String?
    var persistenceError: String?
    private var canSaveBookmarks = true
    private var generation = 0
    private let storage: SavedCatalogStorage
    private let cache: SnapshotCache
    private(set) var summaries: [String: LocalSummary] = [:]
    private(set) var summaryMessages: [String: String] = [:]
    private(set) var summarizingID: String?
    @ObservationIgnored private var summaryTask: Task<Void, Never>?
    private var summaryGeneration = 0
    private let summaryStorage: LocalSummaryStorage

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GitMorning")
        discoveryStorage = DiscoveryStorage(url: base.appendingPathComponent("discovery-v1.json"))
        do { discovery = try discoveryStorage.load() }
        catch { canSaveDiscovery = false; persistenceError = "Could not read reading history. Writes are paused to protect your notes." }
        storage = SavedCatalogStorage(url: base.appendingPathComponent("saved-catalog-v1.json"))
        cache = SnapshotCache(directory: base.appendingPathComponent("snapshots"))
        summaryStorage = LocalSummaryStorage(directory: base.appendingPathComponent("summaries"))
        do {
            if let saved = try storage.load() {
                bookmarks = saved.bookmarks; savedRepositories = saved.repositories
            } else {
                // Preserve older IDs without showing demo projects as real repositories.
                bookmarks = try BookmarkStorage(url: base.appendingPathComponent("bookmarks.json")).load()
            }
        } catch {
            canSaveBookmarks = false
            persistenceError = "Could not read Saved. Writes are paused to protect the existing file in Application Support/GitMorning."
        }
        loadLocal()
    }

    var key: SnapshotKey? { try? SnapshotKey(period: feed == .weekly ? "weekly" : "daily", language: language == "All languages" ? "all" : language) }
    var requestID: String { feed.rawValue + "|" + language }
    var savedCount: Int { bookmarks.filter { savedRepositories[$0.repositoryID] != nil }.count }
    var repositories: [Repository] {
        if feed == .saved { return Array(savedRepositories.values) }
        return snapshot.map(Repository.from) ?? []
    }
    var visible: [Repository] {
        Catalog.filter(repositories, feed: feed, language: feed == .saved && language != "All languages" ? language : nil, query: "", bookmarks: bookmarks).filter { repository in
            let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let reading = reading(repository.id)
            if readingFilter == "Hidden" { if !reading.hidden { return false } }
            else if reading.hidden { return false }
            if readingFilter == "Unread" && reading.read { return false }
            if readingFilter == "Since last visit" {
                guard let change = rankChange(repository.id) else { return false }
                switch change { case .new: break; case .moved(let delta): if delta <= 0 { return false } }
            }
            return needle.isEmpty || "\(repository.fullName) \(repository.summary) \(repository.readmeExcerpt ?? "") \(translatedSearchDescriptions[repository.id] ?? "") \(summaries[repository.id]?.text ?? "")".localizedStandardContains(needle)
        }
    }
    var selected: Repository? { visible.first { $0.id == selectedID } }
    var collectedLabel: String {
        if feed == .saved { return "At time of saving" }
        guard let date = snapshot?.collectedDate else { return "No collection timestamp" }
        // Short enough for one status line: time only for today, otherwise month, day, and time.
        let locale = (InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .matching()).locale
        return Calendar.current.isDateInToday(date) ? date.formatted(.dateTime.hour().minute().locale(locale))
            : date.formatted(.dateTime.month().day().hour().minute().locale(locale))
    }
    func isSaved(_ repository: Repository) -> Bool { bookmarks.contains { $0.repositoryID == repository.id } }
    func selectVisible() { if !visible.contains(where: { $0.id == selectedID }) { selectedID = visible.first?.id } }
    func changeFeed() { generation += 1; query = ""; language = "All languages"; readingFilter = "All projects"; loadLocal() }
    func changeLanguage() { generation += 1; loadLocal() }

    private func bundledData(_ key: SnapshotKey) -> Data? {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let path = Bundle.main.resourceURL?.appendingPathComponent("Snapshots").appendingPathComponent(key.filename) else { return nil }
            return try? Data(contentsOf: path)
        }
        guard let path = Bundle.module.url(forResource: key.filename, withExtension: nil, subdirectory: "Snapshots") else { return nil }
        return try? Data(contentsOf: path)
    }

    func loadLocal() {
        if feed == .saved { snapshot = nil; status = "Projects saved on this Mac"; restoreSummaries(); selectVisible(); return }
        guard let key else { return }
        let bundled = bundledData(key).flatMap { try? key.decode($0) }
        let cached = (try? cache.load(key)).flatMap { try? key.decode($0) }
        if let cached, (cached.collectedDate ?? .distantPast) >= (bundled?.collectedDate ?? .distantPast) {
            snapshot = cached; status = "Last downloaded snapshot"
        } else if let bundled {
            snapshot = bundled; status = "Bundled GitHub snapshot"
        } else {
            snapshot = nil; status = "No snapshot for this period and language. Refresh to fetch GitHub Trending."
        }
        recordVisit()
        restoreSummaries()
        selectVisible()
    }

    private func restoreSummaries() {
        for repository in repositories {
            summaries[repository.id] = try? summaryStorage.load(repositoryID: repository.id, description: repository.introduction, modelVersion: OnDeviceSummary.modelVersion)
        }
    }

    func refresh(baseURL: String, manual: Bool = false) async {
        generation += 1
        let requestGeneration = generation
        isLoading = false
        loadLocal()
        guard feed != .saved, let key else { return }
        isLoading = true
        defer { if generation == requestGeneration { isLoading = false } }
        do {
            let (data, origin) = try await TrendingSource.load(key, customAddress: baseURL)
            try Task.checkCancellation()
            guard requestGeneration == generation, self.key == key, feed != .saved else { return }
            let incoming = try key.decode(data)
            // The hourly shared feed can be older than a list fetched directly earlier; keep the newer one.
            if let old = snapshot?.collectedDate, let new = incoming.collectedDate, new < old { status = "Up to date · newest list kept"; return }
            try cache.save(data, for: key)
            snapshot = incoming
            status = Self.statusLabel(origin)
            recordVisit()
            restoreSummaries()
            selectVisible()
        } catch {
            guard !Task.isCancelled, requestGeneration == generation else { return }
            status = snapshot == nil ? "Could not load data. Check the address and connection." : "Refresh failed · showing the last valid snapshot."
        }
    }

    static func statusLabel(_ origin: TrendingSource.Origin) -> String {
        switch origin {
        case .sharedFeed: return "Shared feed"
        case .github: return "Live GitHub Trending"
        case .staleSharedFeed: return "Shared feed · GitHub unreachable"
        case .customFeed: return "Downloaded snapshot"
        }
    }
    func reading(_ id: String) -> ProjectReading { discovery.projects[id] ?? ProjectReading() }
    var hiddenIDs: Set<String> { Set(discovery.projects.filter { $0.value.hidden }.keys) }
    /// Show one project from today's daily list, e.g. from the morning brief.
    func reveal(_ id: String) {
        feed = .daily; language = "All languages"; readingFilter = "All projects"; query = ""
        changeFeed()
        selectedID = id
        selectVisible()
    }
    var hasBaseline: Bool { key.flatMap { baselines[$0.filename] } != nil }
    func rankChange(_ id: String) -> RankChange? {
        guard feed != .saved, let key, let baseline = baselines[key.filename],
              let index = snapshot?.repositories.firstIndex(where: { $0.id == id }) else { return nil }
        return baseline.change(for: id, currentRank: index + 1)
    }
    private func recordVisit() {
        guard let key, let snapshot else { return }
        if visitedKeys.insert(key.filename).inserted { baselines[key.filename] = discovery.visits[key.filename] }
        let visit = VisitSnapshot(collectedAt: snapshot.collectedAt, ids: snapshot.repositories.map(\.id))
        guard discovery.visits[key.filename] != visit else { return }
        var next = discovery; next.visits[key.filename] = visit
        persistDiscovery(next)
    }
    private func persistDiscovery(_ next: DiscoveryCatalog) {
        guard canSaveDiscovery else { message = persistenceError; return }
        do { try discoveryStorage.save(next); discovery = next }
        catch { message = "Could not save reading history or notes. Check disk space and permissions." }
    }
    func updateReading(_ id: String, _ change: (inout ProjectReading) -> Void) {
        var next = discovery
        var item = reading(id); change(&item); next.projects[id] = item
        persistDiscovery(next); selectVisible()
    }

    func toggleBookmark(_ repository: Repository) {
        guard canSaveBookmarks else { message = persistenceError; return }
        var updated = bookmarks
        var catalog = savedRepositories
        if isSaved(repository) { updated.removeAll { $0.repositoryID == repository.id }; catalog.removeValue(forKey: repository.id) }
        else { updated.append(Bookmark(repositoryID: repository.id)); catalog[repository.id] = repository }
        do {
            try storage.save(SavedCatalog(bookmarks: updated, repositories: catalog))
            bookmarks = updated; savedRepositories = catalog; selectVisible()
        } catch { message = "Could not save changes. Check disk space and file permissions. Existing saved projects are unchanged." }
    }

    func showSource(_ repository: Repository? = nil) {
        guard let repository = repository ?? selected, let url = repository.githubURL else { return }
        if !NSWorkspace.shared.open(url) { message = "Could not open GitHub in your default browser." }
    }

    func prepareSummary() {
        cancelSummary()
        guard let repository = selected else { return }
        do {
            summaries[repository.id] = try summaryStorage.load(repositoryID: repository.id, description: repository.introduction, modelVersion: OnDeviceSummary.modelVersion)
        } catch { summaryMessages[repository.id] = "Could not read the saved explanation. You can generate it again." }
    }

    func startSummary(_ repository: Repository) {
        guard summarizingID == nil else { return }
        if let reason = OnDeviceSummary.unavailableReason { summaryMessages[repository.id] = reason; return }
        summarizingID = repository.id
        summaryGeneration += 1
        let requestGeneration = summaryGeneration
        summaryMessages[repository.id] = "Fetching the README before generating a Korean explanation on this Mac."
        summaryTask = Task {
            defer { if summaryGeneration == requestGeneration { summarizingID = nil } }
            do {
                let document = try await ReadmeReader(cache: .app).load(repository)
                try Task.checkCancellation()
                if let cached = summaries[repository.id], cached.description == repository.introduction,
                   cached.sourceHash == document.hash, cached.modelVersion == OnDeviceSummary.modelVersion {
                    summaryMessages[repository.id] = "The README is unchanged. Reusing the saved explanation."
                    return
                }
                summaryMessages[repository.id] = "Generating a Korean explanation with the on-device model."
                let text = try await OnDeviceSummary.generate(repository: repository, document: document)
                try Task.checkCancellation()
                let item = LocalSummary(repositoryID: repository.id, description: repository.introduction, text: text, sourceURL: document.sourceURL, sourceHash: document.hash, modelVersion: OnDeviceSummary.modelVersion)
                summaries[repository.id] = item
                do {
                    try summaryStorage.save(item)
                    summaryMessages[repository.id] = nil
                } catch { summaryMessages[repository.id] = "Explanation generated, but it could not be saved. Check disk space." }
            } catch ReadmeError.rateLimited {
                summaryMessages[repository.id] = "GitHub’s hourly limit for README requests on this network was reached. Try again later. Browsing is not affected."
            } catch {
                guard !Task.isCancelled else { return }
                summaryMessages[repository.id] = "Could not generate an explanation. Check your connection, GitHub rate limit, and Apple Intelligence. The original and any saved explanation are preserved."
            }
        }
    }

    func cancelSummary() {
        summaryGeneration += 1
        summaryTask?.cancel(); summaryTask = nil
        if let id = summarizingID { summaryMessages[id] = "Generation cancelled. You can try again." }
        summarizingID = nil
    }
}
