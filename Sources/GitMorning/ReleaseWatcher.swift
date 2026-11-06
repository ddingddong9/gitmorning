import SwiftUI
import UserNotifications
import GitMorningCore

/// Checks saved projects for new stable releases while GitMorning runs (the menu bar keeps it running).
/// Each project is read from its public releases.atom page at most twice a day, one at a time; no API
/// request, account, or server. A project's first check only records what is current.
@MainActor @Observable
final class ReleaseWatcher {
    private(set) var state: ReleaseState
    /// Supplies the saved projects' IDs.
    @ObservationIgnored var savedIDs: () -> [String] = { [] }
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var checking = false
    private let storage: ReleaseStateStorage

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GitMorning")
        storage = ReleaseStateStorage(url: base.appendingPathComponent("releases-v1.json"))
        state = storage.load()
    }

    private var defaults: UserDefaults { .standard }
    var isEnabled: Bool { defaults.object(forKey: "releaseChecks") as? Bool ?? true }
    private var notifies: Bool { defaults.bool(forKey: "releaseNotification") }
    private var language: InterfaceLanguage { InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .matching() }

    func unseen(_ id: String) -> ReleaseInfo? { isEnabled ? state.unseen(id) : nil }
    func latest(_ id: String) -> ReleaseInfo? { isEnabled ? state.latest[id] : nil }
    var unseenCount: Int { isEnabled ? savedIDs().filter { state.unseen($0) != nil }.count : 0 }
    func markSeen(_ id: String) {
        guard state.unseen(id) != nil else { return }
        state.markSeen(id); try? storage.save(state)
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))  // Let the window and the brief load first.
            while !Task.isCancelled {
                await self?.checkDue()
                try? await Task.sleep(for: .seconds(1800))
            }
        }
    }

    func checkDue() async {
        guard isEnabled, !checking else { return }
        checking = true
        defer { checking = false }
        let ids = savedIDs()
        state.keep(only: Set(ids))
        var found: [(String, ReleaseInfo)] = []
        for id in state.due(ids, now: Date()) {
            guard !Task.isCancelled, let result = await Self.fetch(id) else { continue }  // network trouble: retry later
            if let release = state.record(id, release: result.release, at: Date()) { found.append((id, release)) }
            try? storage.save(state)
            try? await Task.sleep(for: .seconds(1))  // Be gentle with github.com.
        }
        if !found.isEmpty && notifies { await notify(found) }
    }

    private struct Result { let release: ReleaseInfo? }
    /// nil when the check could not complete; `Result(release: nil)` when the project has no stable release.
    private static func fetch(_ id: String) async -> Result? {
        guard let url = ReleaseFeed.url(for: id) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("application/atom+xml", forHTTPHeaderField: "Accept")
        request.setValue("GitMorning", forHTTPHeaderField: "User-Agent")
        guard let (bytes, response) = try? await session.bytes(for: request), let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return Result(release: nil) }
        guard http.statusCode == 200, response.expectedContentLength <= limit else { return nil }
        var data = Data()
        do {
            for try await byte in bytes {
                guard data.count < limit else { return nil }
                data.append(byte)
            }
        } catch { return nil }
        return Result(release: ReleaseFeed.latest(atom: data, repository: id))
    }

    private static let limit = 2_000_000
    /// Isolated from the app's cookies and cache; follows redirects only to github.com over HTTPS (renamed repositories).
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: GitHubOnlyRedirects(), delegateQueue: nil)
    }()

    private func notify(_ found: [(String, ReleaseInfo)]) async {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = language.text(found.count == 1 ? "New release of a saved project" : "New releases of saved projects")
        content.body = found.prefix(4).map { "\($0.0) \($0.1.tag)" }.joined(separator: ", ")
        try? await center.add(UNNotificationRequest(identifier: "releases-" + UUID().uuidString, content: content, trigger: nil))
    }
}

private final class GitHubOnlyRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let ok = request.url?.scheme == "https" && request.url?.host?.lowercased() == "github.com"
        completionHandler(ok ? request : nil)
    }
}
