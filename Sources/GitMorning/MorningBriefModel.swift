import SwiftUI
import AppKit
import UserNotifications
import GitMorningCore

/// Builds the daily brief while the app runs (the menu bar keeps it running after
/// the window closes). No server, account, or background agent: if GitMorning is
/// not running at the chosen time, the brief is built the next time it is.
@MainActor @Observable
final class MorningBriefModel {
    private(set) var brief: MorningBrief?
    private(set) var isLoading = false
    private(set) var problem: String?
    /// Supplies repositories the user hid, so the brief never resurfaces them.
    @ObservationIgnored var hiddenIDs: () -> Set<String> = { [] }
    @ObservationIgnored private var loop: Task<Void, Never>?
    private let storage: MorningBriefStorage
    private let cache: SnapshotCache

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GitMorning")
        storage = MorningBriefStorage(url: base.appendingPathComponent("brief-v1.json"))
        cache = SnapshotCache(directory: base.appendingPathComponent("snapshots"))
        // The brief is derived data; an unreadable file is replaced by the next brief.
        do { brief = try storage.load() } catch { problem = "Could not read the saved brief. The next brief will replace it." }
    }

    private var defaults: UserDefaults { .standard }
    var minuteOfDay: Int { defaults.object(forKey: "briefMinute") as? Int ?? MorningSchedule.defaultMinute }
    private var notifies: Bool { defaults.bool(forKey: "briefNotification") }
    private var language: InterfaceLanguage { InterfaceLanguage(rawValue: defaults.string(forKey: "interfaceLanguage") ?? "") ?? .matching() }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if MorningSchedule.isDue(now: Date(), minuteOfDay: minuteOfDay, lastDay: brief?.day) { await generate(scheduled: true) }
                // Wake at the next due time, and at least every 15 minutes so sleep,
                // clock changes, failed fetches, and a changed brief time are picked up.
                let wait = MorningSchedule.nextDue(after: Date(), minuteOfDay: minuteOfDay).timeIntervalSinceNow
                try? await Task.sleep(for: .seconds(min(max(wait, 30), 900)))
            }
        }
    }

    func generate(scheduled: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let key = try SnapshotKey(period: "daily", language: "all")
            let (data, _) = try await TrendingSource.load(key, customAddress: defaults.string(forKey: "feedBaseURL") ?? "")
            let snapshot = try key.decode(data)
            try? cache.save(data, for: key) // The main list can reuse this validated download.
            let now = Date()
            let next = MorningBrief.build(from: snapshot, day: MorningSchedule.day(now), now: now, earlier: brief, hidden: hiddenIDs())
            brief = next
            do { try storage.save(next); problem = nil }
            catch { problem = "The brief was updated but could not be saved on this Mac." }
            if scheduled && notifies { await notify(next) }
        } catch {
            problem = brief == nil ? "Could not get today’s brief. Check your connection." : "Could not update the brief. Showing the last one."
        }
    }

    /// One line used by the menu and the notification.
    func headline(_ brief: MorningBrief, language: InterfaceLanguage) -> String {
        if brief.isFirst { return language.text("Today’s top projects") }
        if !brief.hasNews { return language.text("No new projects since yesterday") }
        return "\(language.text("New")) \(brief.newCount) · \(language.text("Rising")) \(brief.risingCount)"
    }

    private func notify(_ brief: MorningBrief) async {
        guard Bundle.main.bundleIdentifier != nil, brief.isFirst || brief.hasNews else { return }
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = language.text("Morning brief")
        content.subtitle = headline(brief, language: language)
        content.body = brief.items.prefix(3).map(\.id).joined(separator: ", ")
        try? await center.add(UNNotificationRequest(identifier: "morning-brief-" + brief.day, content: content, trigger: nil))
    }

    static func requestNotificationPermission() async -> Bool {
        guard Bundle.main.bundleIdentifier != nil else { return false }
        return (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }
}

/// Opens the main window when a brief notification is clicked, even if it was closed.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if Bundle.main.bundleIdentifier != nil { UNUserNotificationCenter.current().delegate = self }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { Self.showMainWindow() }
    }
    /// Same path as clicking the Dock icon: SwiftUI reopens the main Window scene if needed.
    @MainActor static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil); return
        }
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
                                           targetDescriptor: NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier),
                                           returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        _ = try? event.sendEvent(options: [.noReply], timeout: 1)
    }
}
