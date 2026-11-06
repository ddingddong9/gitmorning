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
    @AppStorage("feedBaseURL") private var baseURL = ""
    @ViewState<SettingsTab> private var tab = .general
    @ViewState<String> private var draft = ""
    @ViewState<String> private var feedback = ""
    @ViewState<Bool> private var invalidAddress = false
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

    private enum SettingsTab { case general, brief, language, updates, data }
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
                data.tag(SettingsTab.data)
                    .tabItem { Label(ui("Data"), systemImage: "externaldrive") }
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
            draft = baseURL
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
            } header: { Text(ui("Make it comfortable")) }
              footer: { Text(ui("Changes apply immediately and are remembered on this Mac.")) }
            Section(ui("Reading preview")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(ui("Discover what’s next.")).font(typography.heading)
                    Text(ui("Read original project descriptions, save interesting tools, and explore at your own pace."))
                        .font(typography.body).lineSpacing(5)
                    Label(ui("Original descriptions · no AI required"), systemImage: "text.alignleft")
                        .font(typography.metadata).foregroundStyle(.secondary)
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
              footer: { Text(ui("Once a day after this time, GitMorning compares today’s Trending with yesterday’s brief and lists what is new or rising. It runs only while GitMorning is open; the menu bar keeps it open after you close the window. No account or server.")) }
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
          footer: { Text(ui("Twice a day while GitMorning is open, it reads each saved project’s public release page on GitHub. Nightly, beta, and release-candidate builds are skipped. A new release shows in Saved and, if you turn it on, as a notification.")) }
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
          footer: { Text(ui("Projects in these languages, or with these words in their name, description, or README, come first in the morning brief and are marked with a star. Separate keywords with commas. Today’s Trending can also show only them.")) }
    }

    private var language: some View {
        Form {
            Section {
                Picker(ui("Interface language"), selection: $interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { Text($0.title).tag($0.rawValue) }
                }.accessibilityIdentifier("settingsInterfaceLanguage")
                Text(ui("Repository descriptions automatically follow this language using on-device translation. The original is always available."))
                    .foregroundStyle(.secondary)
            } header: { Text(ui("Follows your Mac’s language until you choose")) }
            Section {
                Toggle(ui("Automatically translate descriptions"), isOn: $autoTranslateDescriptions)
                    .accessibilityIdentifier("settingsAutoTranslation")
                Text(ui("Uses Apple’s on-device translation on macOS 15 or later. Language downloads may require your approval. No paid API or Apple Intelligence is required. Results are saved on this Mac."))
                    .foregroundStyle(.secondary)
            } header: { Text(ui("Description translation")) }
            Section {
                Label(ui("Generate only when requested"), systemImage: "hand.tap")
                Text(ui("Open a project, expand Korean explanation, and choose Explain in Korean. The model runs on this Mac without a paid API."))
                    .foregroundStyle(.secondary)
            } header: { Text(ui("Optional Korean explanations")) }
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
            } header: { Text(ui("Keep GitMorning up to date")) }
            Section {
                Toggle(ui("Automatically check for updates"), isOn: $updater.automaticallyChecks)
                    .disabled(!updater.configured).accessibilityIdentifier("settingsAutomaticUpdates")
                Text(ui(updater.configured
                     ? "New releases appear in an update window. You choose when to install and relaunch, skip that version, or be reminded later. Automatic installation is off."
                     : "This development build has no update feed configured. Automatic checking is available in distribution builds."))
                    .foregroundStyle(.secondary)
            } header: { Text(ui("You stay in control")) }
        }.formStyle(.grouped)
    }

    private var data: some View {
        Form {
            Section {
                Label(ui(baseURL.isEmpty ? "Shared GitMorning feed" : "Custom HTTPS feed"), systemImage: "externaldrive")
                Text(ui(baseURL.isEmpty ? "No setup needed. GitMorning reads a shared list collected from GitHub Trending several times a day, and reads GitHub directly if that list is unavailable or more than 8 hours old. When a refresh fails, the last valid snapshot stays available offline." : "GitMorning reads only this address. When a refresh fails, the last valid snapshot stays available offline."))
                    .foregroundStyle(.secondary)
            } header: { Text(ui("Data source")) }
            Section {
                TextField(ui("HTTPS feed address"), text: $draft, prompt: Text(ui("https://example.com/snapshots")))
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("feedBaseURL")
                Text(ui("Optional. Leave empty to use the shared feed, or enter a compatible HTTPS feed folder."))
                    .foregroundStyle(.secondary)
                HStack {
                    Button(ui("Apply address"), action: applyAddress)
                        .accessibilityIdentifier("settingsApplyFeed")
                    Button(ui("Use the shared feed")) {
                        draft = ""
                        applyAddress()
                    }.disabled(baseURL.isEmpty && draft.isEmpty)
                }
                if !feedback.isEmpty {
                    Label(ui(feedback), systemImage: invalidAddress ? "exclamationmark.circle" : "checkmark.circle")
                        .foregroundStyle(invalidAddress ? Color.orange : Color.secondary)
                        .accessibilityIdentifier("feedURLFeedback")
                }
            } header: { Text(ui("Custom feed")) }
              footer: { Text(ui("Changing the source does not remove saved projects or explanations.")) }
        }.formStyle(.grouped)
    }

    private func applyAddress() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if !value.isEmpty { _ = try FeedEndpoint(value) }
            baseURL = value
            draft = value
            invalidAddress = false
            feedback = value.isEmpty ? "Using the shared feed with GitHub as backup and an offline cache." : "Address applied. Refresh the list to check the feed."
        } catch {
            invalidAddress = true
            feedback = "Enter an HTTPS folder URL without credentials, a query, or a fragment."
        }
    }
}
