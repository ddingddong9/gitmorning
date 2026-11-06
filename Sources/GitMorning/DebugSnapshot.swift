#if DEBUG
import SwiftUI
import AppKit
import WebKit
import GitMorningCore

/// Debug builds only: `GITMORNING_SNAPSHOT_DIR=/path GitMorning.app/Contents/MacOS/GitMorning`
/// saves the main window, Settings, and the morning brief panel as PNGs, then quits.
/// The app draws its own windows, so no screen-recording permission is needed.
/// Optional `GITMORNING_SNAPSHOT_APPEARANCE=dark`.
@MainActor enum DebugSnapshot {
    static func runIfRequested(brief: MorningBriefModel, state: AppState) {
        guard let path = ProcessInfo.processInfo.environment["GITMORNING_SNAPSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if ProcessInfo.processInfo.environment["GITMORNING_SNAPSHOT_APPEARANCE"] == "dark" { NSApplication.shared.appearance = NSAppearance(named: .darkAqua) }
        Task { @MainActor in
            // Optional: GITMORNING_SNAPSHOT_QUERY filters the list, e.g. to capture the empty state.
            if let query = ProcessInfo.processInfo.environment["GITMORNING_SNAPSHOT_QUERY"] {
                try? await Task.sleep(for: .seconds(2)); state.query = query
            }
            try? await Task.sleep(for: .seconds(6)) // Let lists, translations, and layout settle.
            // Optional: GITMORNING_SNAPSHOT_HISTORY=/path/history.json shows a rank history (not cached).
            if let path = ProcessInfo.processInfo.environment["GITMORNING_SNAPSHOT_HISTORY"],
               let data = FileManager.default.contents(atPath: path) {
                state.debugUseHistory(data); try? await Task.sleep(for: .seconds(1))
            }
            if let main = NSApp.windows.first(where: { $0.identifier?.rawValue.hasPrefix("main") == true }) { save(main, to: directory.appendingPathComponent("main.png")) }
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 560), styleMask: [.titled], backing: .buffered, defer: false)
            let size = ReadingSize.fromStored(UserDefaults.standard.string(forKey: "readingSize") ?? "")
            panel.contentView = NSHostingView(rootView: MorningBriefMenu(model: brief, state: state)
                .environment(\.appTypography, AppTypography(size: size)).fixedSize(horizontal: false, vertical: true))
            panel.setContentSize(panel.contentView?.fittingSize ?? panel.frame.size)
            panel.orderFront(nil)
            try? await Task.sleep(for: .seconds(1))
            save(panel, to: directory.appendingPathComponent("brief.png"))
            panel.close()
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            try? await Task.sleep(for: .seconds(2))
            let main = NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("main") == true }
            if let settings = NSApp.windows.first(where: { $0.isVisible && $0 !== main && $0.canBecomeKey && $0.frame.width > 400 }) {
                save(settings, to: directory.appendingPathComponent("settings.png"))
            }
            // Optional: GITMORNING_SNAPSHOT_README=owner/name opens the README preview and saves the window
            // (readme-window.png) and its web content (readme.png).
            if let id = ProcessInfo.processInfo.environment["GITMORNING_SNAPSHOT_README"] {
                let repository = Repository(id: id, owner: String(id.split(separator: "/").first ?? ""), language: "", summary: "", introduction: "",
                                            features: [], usage: "", stars: nil, dailyGain: nil, weeklyGain: nil)
                let size = ReadingSize.fromStored(UserDefaults.standard.string(forKey: "readingSize") ?? "")
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 660), styleMask: [.titled], backing: .buffered, defer: false)
                window.contentView = NSHostingView(rootView: ReadmePreviewSnapshot(repository: repository).environment(\.appTypography, AppTypography(size: size)))
                window.orderFront(nil)
                try? await Task.sleep(for: .seconds(10))
                save(window, to: directory.appendingPathComponent("readme-window.png"))
                func webView(in view: NSView) -> WKWebView? { (view as? WKWebView) ?? view.subviews.lazy.compactMap(webView).first }
                if let web = window.contentView.flatMap(webView), let image = try? await web.takeSnapshot(configuration: nil),
                   let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: directory.appendingPathComponent("readme.png"))
                }
                window.close()
            }
            let titles = NSApp.windows.map { "\($0.identifier?.rawValue ?? "-") | \($0.title) | visible \($0.isVisible) | \(Int($0.frame.width))x\(Int($0.frame.height))" }
            try? titles.joined(separator: "\n").write(to: directory.appendingPathComponent("windows.txt"), atomically: true, encoding: .utf8)
            NSApp.terminate(nil)
        }
    }

    private static func save(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
