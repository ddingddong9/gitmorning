import SwiftUI
import AppKit

typealias ViewState<Value> = SwiftUI.State<Value>

enum Appearance: String, CaseIterable, Identifiable {
    case system = "System", light = "Light", dark = "Dark"
    var id: String { rawValue }
    static func fromStored(_ value: String) -> Appearance {
        switch value {
        case "시스템": return .system
        case "라이트": return .light
        case "다크": return .dark
        default: return Appearance(rawValue: value) ?? .light
        }
    }
    var scheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
}

extension Notification.Name {
    static let focusSearch = Notification.Name("GitMorning.focusSearch")
    static let refreshFeed = Notification.Name("GitMorning.refreshFeed")
}

@main
struct GitMorningApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ViewState<AppState> private var state: AppState
    @ViewState<MorningBriefModel> private var brief: MorningBriefModel
    @AppStorage("showMenuBar") private var showMenuBar = true
    @StateObject private var updater = AppUpdater()

    init() {
        InterfaceLanguage.registerSystemDefault()
        let state = AppState(), brief = MorningBriefModel()
        brief.hiddenIDs = { [weak state] in state?.hiddenIDs ?? [] }
        brief.start()
        #if DEBUG
        DebugSnapshot.runIfRequested(brief: brief, state: state)
        #endif
        _state = ViewState(initialValue: state)
        _brief = ViewState(initialValue: brief)
    }
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue
    @AppStorage("readingSize") private var readingSize = ReadingSize.standard.rawValue

    var body: some Scene {
        Window("GitMorning", id: "main") {
            ContentView(state: state)
                .environment(\.appTypography, AppTypography(size: ReadingSize.fromStored(readingSize)))
                .environment(\.locale, (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).locale)
                .preferredColorScheme(Appearance.fromStored(appearance).scheme)
                .frame(minWidth: 900, minHeight: 580)
                .background(WindowPlacement())
        }
        .defaultPosition(.center)
        // The sidebar shows the app name; a second title in the toolbar was redundant.
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1060, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(ui("Check for Updates…")) { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
            }
            CommandGroup(after: .textEditing) {
                Button(ui("Search this list")) { NotificationCenter.default.post(name: .focusSearch, object: nil) }
                    .keyboardShortcut("f")
            }
            CommandMenu(ui("Project")) {
                Button(ui("Save / unsave")) { if let selected = state.selected { state.toggleBookmark(selected) } }
                    .keyboardShortcut("d").disabled(state.selected == nil)
                Button(ui("Open on GitHub")) { state.showSource() }
                    .keyboardShortcut("o", modifiers: [.command, .shift]).disabled(state.selected == nil)
                Divider()
                Button(ui("Refresh")) { NotificationCenter.default.post(name: .refreshFeed, object: nil) }
                    .keyboardShortcut("r")
            }
        }
        // Also keeps the app running after the window closes, so the brief can update each morning.
        MenuBarExtra(isInserted: $showMenuBar) {
            MorningBriefMenu(model: brief, state: state)
                .environment(\.appTypography, AppTypography(size: ReadingSize.fromStored(readingSize)))
                .environment(\.locale, (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).locale)
                .preferredColorScheme(Appearance.fromStored(appearance).scheme)
        } label: {
            Image(systemName: brief.brief?.hasNews == true ? "sun.max.fill" : "sun.horizon")
                .accessibilityLabel(ui("Morning brief"))
        }
        .menuBarExtraStyle(.window)
        Settings {
            SettingsView()
            .environmentObject(updater)
            .environment(\.appTypography, AppTypography(size: ReadingSize.fromStored(readingSize)))
            .environment(\.locale, (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).locale)
                .preferredColorScheme(Appearance.fromStored(appearance).scheme)
        }
    }
}

// Center only once per launch; later resizes and user positioning remain intact.
struct WindowPlacement: NSViewRepresentable {
    func makeNSView(context: Context) -> PlacementView { PlacementView() }
    func updateNSView(_ nsView: PlacementView, context: Context) {}
    final class PlacementView: NSView {
        private var placed = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, !placed else { return }
            placed = true
            DispatchQueue.main.async {
                let visible = (window.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
                let width = min(1060, visible.width - 60)
                let height = min(748, visible.height - 60)
                window.setFrame(NSRect(x: visible.midX - width / 2, y: visible.midY - height / 2, width: width, height: height), display: true)
            }
        }
    }
}
