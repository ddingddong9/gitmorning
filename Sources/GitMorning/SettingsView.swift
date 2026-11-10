import SwiftUI
import ServiceManagement
import GitMorningCore

struct SettingsView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    @Environment(\.appTypography) private var typography
    @EnvironmentObject private var updater: AppUpdater
    @AppStorage("appearance") private var appearance = Appearance.light.rawValue
    @AppStorage("readingSize") private var readingSize = ReadingSize.standard.rawValue
    @AppStorage("autoTranslateDescriptions") private var autoTranslateDescriptions = true
    @ViewState<SettingsTab> private var tab = .general
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("briefNotification") private var briefNotification = false
    @AppStorage("interestLanguages") private var interestLanguages = ""
    @AppStorage("interestKeywords") private var interestKeywords = ""
    @ViewState<String> private var keywordDraft = ""
    @AppStorage("releaseChecks") private var releaseChecks = true
    @AppStorage("releaseNotification") private var releaseNotification = false
    @ViewState<String> private var releaseProblem = ""
    @AppStorage("briefMinute") private var briefMinute = MorningSchedule.defaultMinute
    @ViewState<String> private var notificationProblem = ""
    @ViewState<Bool> private var opensAtLogin = LoginItem.isEnabled
    @ViewState<String> private var loginProblem = ""

    enum SettingsTab: CaseIterable { case general, brief, language, updates }
    init(tab: SettingsTab = .general) { _tab = ViewState(initialValue: tab) }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                general.tag(SettingsTab.general)
                    .tabItem { Label(ui("General"), systemImage: "slider.horizontal.3") }
                brief.tag(SettingsTab.brief)
                    .tabItem { Label(ui("Morning brief"), systemImage: "sun.horizon") }
                language.tag(SettingsTab.language)
                    .tabItem { Label(ui("Language & AI"), systemImage: "globe") }
                updates.tag(SettingsTab.updates)
                    .tabItem { Label(ui("Updates"), systemImage: "arrow.triangle.2.circlepath") }
            }
            Divider()
            HStack {
                Text("GitMorning \(version)").foregroundStyle(.secondary)
                Spacer()
                Link(ui("GitHub"), destination: URL(string: "https://github.com/ddingddong9/gitmorning")!)
                Link(ui("Releases"), destination: URL(string: "https://github.com/ddingddong9/gitmorning/releases")!)
            }
            .font(typography.metadata).padding(.horizontal, 24).padding(.vertical, 14)
        }
        .font(typography.body)
        .frame(width: 640, height: 560)
        .onAppear {
            appearance = Appearance.fromStored(appearance).rawValue
            readingSize = ReadingSize.fromStored(readingSize).rawValue
        }
    }

    private var general: some View {
        Form {
            Section {
                Picker(ui("Theme"), selection: $appearance) {
                    ForEach(Appearance.allCases) { Text(ui($0.rawValue)).tag($0.rawValue) }
                }.pickerStyle(.segmented).accessibilityIdentifier("settingsTheme")
                Picker(ui("Text size"), selection: $readingSize) {
                    ForEach(ReadingSize.allCases) { Text(ui($0.rawValue)).tag($0.rawValue) }
                }.pickerStyle(.segmented).accessibilityIdentifier("settingsTextSize")
            }
            Section(ui("Reading preview")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(ui("Discover what’s next.")).font(typography.heading)
                    Text(ui("Read original project descriptions, save interesting tools, and explore at your own pace."))
                        .font(typography.body).lineSpacing(5)
                }.padding(.vertical, 8).accessibilityIdentifier("settingsReadingPreview")
            }
        }.formStyle(.grouped)
    }

    private var briefTime: Binding<Date> {
        Binding(get: { Calendar.current.date(byAdding: .minute, value: briefMinute, to: Calendar.current.startOfDay(for: Date())) ?? Date() },
                set: { let parts = Calendar.current.dateComponents([.hour, .minute], from: $0); briefMinute = (parts.hour ?? 8) * 60 + (parts.minute ?? 0) })
    }

    private var brief: some View {
        Form {
            Section {
                DatePicker(ui("Brief time"), selection: briefTime, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("settingsBriefTime")
                Toggle(ui("Show in menu bar"), isOn: $showMenuBar).accessibilityIdentifier("settingsShowMenuBar")
                Toggle(ui("Open GitMorning at login"), isOn: Binding(get: { opensAtLogin }, set: { value in
                    loginProblem = LoginItem.set(value) ?? ""; opensAtLogin = LoginItem.isEnabled || LoginItem.needsApproval
                })).accessibilityIdentifier("settingsOpenAtLogin")
                if !loginProblem.isEmpty {
                    Text(ui(loginProblem)).foregroundStyle(.orange)
                    if LoginItem.needsApproval { Button(ui("Open Login Items")) { SMAppService.openSystemSettingsLoginItems() } }
                }
                Toggle(ui("Notify me when the brief is ready"), isOn: $briefNotification)
                    .accessibilityIdentifier("settingsBriefNotification")
                    .onChange(of: briefNotification) { _, enabled in
                        guard enabled else { notificationProblem = ""; return }
                        Task {
                            if await MorningBriefModel.requestNotificationPermission() { notificationProblem = "" }
                            else { briefNotification = false; notificationProblem = "Notifications are off for GitMorning. Allow them in System Settings → Notifications." }
                        }
                    }
                if !notificationProblem.isEmpty { Text(ui(notificationProblem)).foregroundStyle(.orange) }
            } header: { Text(ui("Morning brief")) }
              footer: { footnote("Runs only while GitMorning is open. The menu bar keeps it open.") }
            interestsSection
            releasesSection
        }.formStyle(.grouped)
    }

    private var selectedLanguages: Set<String> { Set(Interests(storedLanguages: interestLanguages, storedKeywords: "").languages) }
    private func setLanguage(_ language: String, _ on: Bool) {
        var chosen = Interests.languageChoices.filter { selectedLanguages.contains($0) }
        if on { chosen.append(language) } else { chosen.removeAll { $0 == language } }
        interestLanguages = Interests(languages: Interests.languageChoices.filter { chosen.contains($0) }).storedLanguages
    }
    private var releasesSection: some View {
        Section {
            Toggle(ui("Check saved projects for new releases"), isOn: $releaseChecks).accessibilityIdentifier("settingsReleaseChecks")
            Toggle(ui("Notify me about new releases"), isOn: $releaseNotification)
                .disabled(!releaseChecks).accessibilityIdentifier("settingsReleaseNotification")
                .onChange(of: releaseNotification) { _, enabled in
                    guard enabled else { releaseProblem = ""; return }
                    Task {
                        if await MorningBriefModel.requestNotificationPermission() { releaseProblem = "" }
                        else { releaseNotification = false; releaseProblem = "Notifications are off for GitMorning. Allow them in System Settings → Notifications." }
                    }
                }
            if !releaseProblem.isEmpty { Text(ui(releaseProblem)).foregroundStyle(.orange) }
        } header: { Text(ui("Saved projects")) }
    }

    private var interestsSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), alignment: .leading, spacing: 8) {
                ForEach(Interests.languageChoices, id: \.self) { language in
                    Toggle(language, isOn: Binding(get: { selectedLanguages.contains(language) }, set: { setLanguage(language, $0) }))
                        .toggleStyle(.checkbox)
                }
            }
            TextField(ui("Keywords"), text: $keywordDraft, prompt: Text(ui("agent, terminal, database")))
                .onAppear { keywordDraft = interestKeywords }
                .onSubmit { interestKeywords = Interests(storedLanguages: "", storedKeywords: keywordDraft).storedKeywords; keywordDraft = interestKeywords }
                .onChange(of: keywordDraft) { _, value in interestKeywords = Interests(storedLanguages: "", storedKeywords: value).storedKeywords }
                .accessibilityIdentifier("settingsInterestKeywords")
        } header: { Text(ui("Interests")) }
          footer: { footnote("Matching projects come first in the morning brief, marked with a star. Separate keywords with commas.") }
    }

    private var language: some View {
        Form {
            Section {
                Picker(ui("Interface language"), selection: $interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }.accessibilityIdentifier("settingsInterfaceLanguage")
            }
            Section {
                Toggle(ui("Automatically translate descriptions"), isOn: $autoTranslateDescriptions)
                    .accessibilityIdentifier("settingsAutoTranslation")
            } header: { Text(ui("Description translation")) }
            Section(ui("On-device model")) {
                if let reason = OnDeviceSummary.unavailableReason {
                    Label(ui("Not available"), systemImage: "info.circle")
                    Text(ui(reason)).foregroundStyle(.secondary)
                } else {
                    Label(ui("Ready for Korean explanations"), systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
        }.formStyle(.grouped)
    }

    private var updates: some View {
        Form {
            Section {
                LabeledContent(ui("Installed version"), value: version)
                Button(ui("Check for Updates…")) { updater.checkForUpdates() }
                    .disabled(!updater.canCheck).accessibilityIdentifier("settingsCheckUpdates")
                Toggle(ui("Automatically check for updates"), isOn: $updater.automaticallyChecks)
                    .disabled(!updater.configured).accessibilityIdentifier("settingsAutomaticUpdates")
                if !updater.configured {
                    Text(ui("This development build has no update feed configured. Automatic checking is available in distribution builds."))
                        .foregroundStyle(.secondary)
                }
            }
        }.formStyle(.grouped)
    }

    /// Grouped-form footers wrap with trailing alignment on macOS; keep them left-aligned under the section.
    private func footnote(_ text: String) -> some View {
        Text(ui(text)).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
