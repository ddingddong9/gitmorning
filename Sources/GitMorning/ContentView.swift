import SwiftUI
import AppKit
import UniformTypeIdentifiers
import GitMorningCore

struct ContentView: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    @Environment(\.appTypography) private var typography
    @Bindable var state: AppState
    let releases: ReleaseWatcher
    @AppStorage("feedBaseURL") private var baseURL = ""
    @AppStorage("autoTranslateDescriptions") private var autoTranslateDescriptions = true
    @AppStorage("interestLanguages") private var interestLanguages = ""
    @AppStorage("interestKeywords") private var interestKeywords = ""
    @ViewState<DescriptionTranslations> private var translations = DescriptionTranslations()
    @ViewState<Int> private var translationAttempt = 0
    @FocusState private var searchFocused: Bool
    @ViewState<Repository?> private var previewRepository = nil
    @ViewState<NavigationSplitViewVisibility> private var columnVisibility = .all

    // Split into short stages so each modifier chain type-checks quickly; a single
    // long chain exceeded the CI compiler's type-check time limit.
    var body: some View {
        withLifecycle
            .alert("GitMorning", isPresented: messagePresented) {
                Button(ui("OK"), role: .cancel) { state.message = nil }
            } message: { Text(ui(state.message ?? "")) }
    }
    private var withChanges: some View {
        layout
            .onChange(of: translations.items) { _, _ in updateTranslationSearch() }
            .onChange(of: interfaceLanguage) { _, _ in updateTranslationSearch() }
            .onChange(of: autoTranslateDescriptions) { _, _ in updateTranslationSearch() }
            .onChange(of: translationInputID) { _, _ in updateTranslationSearch() }
    }
    private var withNavigation: some View {
        withChanges
            .onChange(of: state.feed) { _, _ in state.changeFeed() }
            .onChange(of: state.readingFilter) { _, _ in state.selectVisible() }
            .onChange(of: state.query) { _, _ in state.selectVisible() }
            .onChange(of: state.language) { _, _ in state.changeLanguage() }
    }
    private var withLifecycle: some View {
        withNavigation
            .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in searchFocused = true }
            .onReceive(NotificationCenter.default.publisher(for: .refreshFeed)) { _ in manualRefresh() }
            .task(id: refreshID) { await state.refresh(baseURL: baseURL) }
            .task(id: state.selected?.id) { state.prepareSummary() }
            .task { showPersistenceError() }
    }
    private var refreshID: String { state.requestID + "|" + baseURL }
    /// Descriptions plus README excerpts; both are translated and cached the same way.
    private var translationInputs: [Repository] { state.repositories + state.repositories.compactMap(\.readmeExcerptItem) }
    private var translationInputID: String { DescriptionTranslations.inputID(translationInputs, target: interfaceLanguage) }
    private func manualRefresh() { Task { await state.refresh(baseURL: baseURL, manual: true) } }
    private func showPersistenceError() { if let error = state.persistenceError { state.message = error } }
    private var messagePresented: Binding<Bool> {
        Binding(get: { state.message != nil }, set: { if !$0 { state.message = nil } })
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(ui("GitMorning"), systemImage: "chart.line.uptrend.xyaxis")
                .font(typography.brand).padding(.horizontal, AppSpacing.column).padding(.top, 14).padding(.bottom, 10)
            List(selection: $state.feed) {
                Section {
                    ForEach(Feed.allCases) { feed in
                        HStack {
                            Label(ui(feed.title), systemImage: feed.symbol).font(typography.navigation)
                            if feed == .saved && state.savedCount > 0 {
                                Spacer()
                                if releases.unseenCount > 0 {
                                    Image(systemName: "shippingbox.fill").foregroundStyle(.orange).font(typography.metadata)
                                        .help(String(format: ui("%d saved projects have a new release"), releases.unseenCount))
                                }
                                Text(state.savedCount.formatted()).foregroundStyle(.secondary).font(typography.listBody)
                            }
                        }.tag(feed)
                    }
                } header: {
                    Text(ui("Browse")).font(typography.metadata)
                }
            }.listStyle(.sidebar)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
    private var listHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(ui(state.feed.title)).font(typography.heading)
                Spacer()
                if state.isLoading { ProgressView().controlSize(.small).accessibilityLabel(ui("Refreshing")) }
                if state.feed == .saved && state.savedCount > 0 { exportMenu }
            }
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(ui(state.feed == .saved ? "Search saved projects" : "Search this list"), text: $state.query)
                    .textFieldStyle(.plain).font(typography.listBody).focused($searchFocused)
                    .accessibilityIdentifier("repositorySearch")
                if !state.query.isEmpty {
                    Button { state.query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary).help(ui("Clear search"))
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 7))
            HStack(spacing: 8) {
                Picker(ui("Language"), selection: $state.language) {
                    ForEach(["All languages", "Python", "TypeScript", "JavaScript", "Swift", "Go", "Rust"], id: \.self) { Text(ui($0)).tag($0) }
                }.labelsHidden().help(ui("Language"))
                Picker(ui("Show"), selection: $state.readingFilter) {
                    ForEach((state.feed == .saved ? ["All projects", "Unread", "Hidden"] : ["All projects", "Since last visit", "Unread", "Hidden"])
                            + (interestLanguages.isEmpty && interestKeywords.isEmpty ? [] : ["My interests"]), id: \.self) {
                        Text(ui($0)).tag($0)
                    }
                }.labelsHidden().help(ui("Show")).accessibilityIdentifier("readingFilter")
            }.pickerStyle(.menu).font(typography.action)
            if state.readingFilter == "Since last visit" && !state.hasBaseline {
                Text(ui("First visit. Changes appear after your next visit to this list."))
                    .font(typography.metadata).foregroundStyle(.secondary)
            }
        }.padding(.horizontal, AppSpacing.column).padding(.top, 12).padding(.bottom, 10)
    }
    private var exportMenu: some View {
        Menu {
            Button(ui("Copy as Markdown")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(exportMarkdown, forType: .string)
            }
            Button(ui("Save as Markdown…")) { saveExport() }
        } label: { Label(ui("Export"), systemImage: "square.and.arrow.up") }
        .labelStyle(.iconOnly).menuIndicator(.hidden).fixedSize().help(ui("Export saved projects"))
        .accessibilityIdentifier("exportSaved")
    }
    private var exportMarkdown: String {
        SavedExport.markdown(state.exportEntries, exportedAt: Date(),
                             locale: (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).locale, text: ui)
    }
    private func saveExport() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = ui("GitMorning saved projects") + ".md"
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try exportMarkdown.write(to: url, atomically: true, encoding: .utf8) }
        catch { state.message = "Could not save the file. Check the folder and try again." }
    }
    private var listColumn: some View {
        VStack(spacing: 0) {
            listHeader
            Divider()
            // One status line: count on the left, translation state or order on the right.
            HStack(spacing: 6) {
                Text(String(format: ui("%d projects"), state.visible.count))
                Spacer()
                translationStatus
            }.font(typography.metadata).foregroundStyle(.secondary).lineLimit(1)
                .padding(.horizontal, AppSpacing.column).padding(.vertical, 8)
            if state.visible.isEmpty {
                ContentUnavailableView {
                    Label(ui(state.feed == .saved && state.savedCount == 0 ? "No saved projects" : state.snapshot == nil && state.feed != .saved ? "No snapshot available" : "No results"), systemImage: "tray")
                } description: {
                    Text(ui(state.feed == .saved && state.savedCount == 0 ? "Save a project to find it here later." : state.snapshot == nil && state.feed != .saved ? state.status : "Try another search or language."))
                } actions: {
                    if state.feed != .saved { Button(ui("Refresh")) { Task { await state.refresh(baseURL: baseURL, manual: true) } }.disabled(state.isLoading) }
                    Button(ui("Reset filters")) {
                        if state.feed == .saved && state.savedCount == 0 { state.feed = .daily }
                        state.query = ""; state.language = "All languages"; state.readingFilter = "All projects"
                    }
                }
                // Fill the space the list would use, so the header stays at the top and the status line at the bottom.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $state.selectedID) {
                    ForEach(state.visible) { repo in
                        RepositoryRow(repository: repo, rank: state.feed == .saved ? nil : state.repositories.firstIndex(of: repo).map { $0 + 1 }, feed: state.feed, saved: state.isSaved(repo), reading: state.reading(repo.id), change: state.rankChange(repo.id), streak: state.feed == .daily ? state.streak(repo.id) : nil, newRelease: state.feed == .saved ? releases.unseen(repo.id) : nil, translatedDescription: autoTranslateDescriptions ? translations.translation(repo, target: interfaceLanguage) : nil)
                            .tag(repo.id)
                            .contextMenu {
                                Button(ui(state.isSaved(repo) ? "Unsave" : "Save")) { state.toggleBookmark(repo) }
                                Button(ui(state.reading(repo.id).read ? "Mark unread" : "Mark read")) { state.updateReading(repo.id) { $0.read.toggle() } }
                                Button(ui(state.reading(repo.id).hidden ? "Unhide" : "Hide")) { state.updateReading(repo.id) { $0.hidden.toggle() } }
                                Button(ui("Open on GitHub")) { state.showSource(repo) }
                            }
                    }
                }.listStyle(.inset).accessibilityIdentifier("repositoryList")
            }
            Divider()
            Text(ui(state.status) + " · " + ui(state.collectedLabel))
                .font(typography.metadata).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                .help(ui(state.status) + " · " + ui(state.collectedLabel))
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, AppSpacing.column).padding(.vertical, 9)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 460)
    }
    @ViewBuilder private var translationStatus: some View {
        if autoTranslateDescriptions, #available(macOS 15.0, *), translations.isWorking {
            ProgressView().controlSize(.mini); Text(ui("Translating descriptions…"))
        } else if autoTranslateDescriptions, #available(macOS 15.0, *), translations.hasFailures {
            Button(ui("Retry")) { translationAttempt += 1 }.buttonStyle(.link)
                .help(ui("Some descriptions remain in the original language."))
        } else {
            Text(ui(state.feed == .saved ? "Recently saved" : "Trending order"))
        }
    }
    @ViewBuilder private var detailColumn: some View {
        if let selected = state.selected {
            RepositoryDetail(history: state.feed == .daily ? state.history : nil,
                             release: state.isSaved(selected) ? releases.latest(selected.id) : nil,
                             releaseIsNew: releases.unseen(selected.id) != nil,
                             releaseSeen: { releases.markSeen(selected.id) },
                             repository: selected,
                             translatedDescription: autoTranslateDescriptions ? translations.translation(selected, target: interfaceLanguage) : nil,
                             translationMessage: autoTranslateDescriptions ? translations.message(selected, target: interfaceLanguage) : nil,
                             translatedExcerpt: autoTranslateDescriptions ? selected.readmeExcerptItem.flatMap { translations.translation($0, target: interfaceLanguage) } : nil,
                             feed: state.feed, saved: state.isSaved(selected),
                             summary: state.summaries[selected.id], summaryMessage: state.summaryMessages[selected.id],
                             isSummarizing: state.summarizingID == selected.id,
                             summarize: { state.startSummary(selected) }, cancel: { state.cancelSummary() },
                             reading: state.reading(selected.id),
                             updateReading: { value in state.updateReading(selected.id) { $0 = value } },
                             preview: { previewRepository = selected },
                             save: { state.toggleBookmark(selected) }, openSource: { state.showSource(selected) })
        } else {
            ContentUnavailableView(ui("Select a project"), systemImage: "book", description: Text(ui("Choose a project to read its original description. No AI required.")))
        }
    }
    private var layout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) { sidebar } content: { listColumn } detail: { detailColumn }
        .navigationSplitViewStyle(.balanced)
        .background {
            if autoTranslateDescriptions {
                if #available(macOS 15.0, *) {
                    DescriptionTranslationDriver(repositories: translationInputs, target: interfaceLanguage, translations: translations)
                        .id(translationInputID + "|" + String(translationAttempt))
                }
            }
        }
        .sheet(item: $previewRepository) { repository in ReadmePreview(repository: repository) }
        .toolbar {
            ToolbarItem {
                SettingsLink { Label(ui("Settings"), systemImage: "gearshape") }
                    .help(ui("Settings (⌘,)"))
                    .accessibilityIdentifier("openSettingsButton")
            }
            ToolbarItem {
                Button { Task { await state.refresh(baseURL: baseURL, manual: true) } } label: {
                    Label(ui("Refresh"), systemImage: "arrow.clockwise")
                }.help(ui("Refresh (⌘R)")).disabled(state.isLoading || state.feed == .saved)
            }
        }
    }
    private func updateTranslationSearch() {
        state.translatedSearchDescriptions = autoTranslateDescriptions ? Dictionary(uniqueKeysWithValues: state.repositories.compactMap { repository in
            translations.translation(repository, target: interfaceLanguage).map { (repository.id, $0) }
        }) : [:]
        state.selectVisible()
    }
}

private struct RepositoryRow: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    @Environment(\.appTypography) private var typography
    let repository: Repository
    let rank: Int?
    let feed: Feed
    let saved: Bool
    let reading: ProjectReading
    let change: RankChange?
    /// Days in a row on today's list; shown from the second day.
    let streak: Int?
    /// A saved project's release the user has not seen yet.
    let newRelease: ReleaseInfo?
    let translatedDescription: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let rank { Text(rank.formatted()).font(typography.metadata).monospacedDigit().foregroundStyle(.secondary) }
                (Text(repository.owner + " / ").font(typography.owner).foregroundStyle(.secondary) + Text(repository.name).font(typography.listTitle))
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 4)
                if !reading.read { Circle().fill(Color.accentColor).frame(width: 7, height: 7).accessibilityLabel(ui("Unread")) }
            }
            Text(translatedDescription ?? (repository.summary == "No description provided." ? ui(repository.summary) : repository.summary)).font(typography.listBody).foregroundStyle(.primary.opacity(0.85)).lineLimit(2).lineSpacing(typography.listLeading)
            HStack(spacing: 8) {
                Text(ui(repository.language))
                if let change {
                    switch change {
                    case .new: Text(ui("New")).foregroundStyle(.green)
                    case .moved(let delta):
                        if delta > 0 { Text("↑ \(delta)").foregroundStyle(.green) }
                        else if delta < 0 { Text("↓ \(-delta)") }
                    }
                }
                if let streak, streak >= 2 {
                    Label(String(format: ui("%d days"), streak), systemImage: "flame").labelStyle(.titleAndIcon).foregroundStyle(.orange)
                        .help(String(format: ui("On today’s list %d days in a row"), streak))
                }
                if let newRelease {
                    Label(String(format: ui("New release %@"), newRelease.tag), systemImage: "shippingbox").foregroundStyle(.orange).lineLimit(1)
                } else if saved { Image(systemName: "bookmark.fill").accessibilityLabel(ui("Saved")) }
                Spacer()
                Text(ui(repository.gain(for: feed).map { "+" + $0.formatted() } ?? "Growth unavailable"))
                    .monospacedDigit()
            }.font(typography.metadata).foregroundStyle(.secondary)
        }.padding(.vertical, AppSpacing.row)
        .accessibilityElement(children: .combine)
    }
}

private struct RepositoryDetail: View {
    let history: TrendHistory?
    let release: ReleaseInfo?
    let releaseIsNew: Bool
    let releaseSeen: () -> Void
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    private var locale: Locale { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).locale }
    @Environment(\.appTypography) private var typography
    @ViewState<Bool> private var showKorean = false
    let repository: Repository
    let translatedDescription: String?
    let translationMessage: String?
    let translatedExcerpt: String?
    let feed: Feed
    let saved: Bool
    let summary: LocalSummary?
    let summaryMessage: String?
    let isSummarizing: Bool
    let summarize: () -> Void
    let cancel: () -> Void
    let reading: ProjectReading
    let updateReading: (ProjectReading) -> Void
    let preview: () -> Void
    let save: () -> Void
    let openSource: () -> Void

    /// GitHub's description, translated when available; the README excerpt when GitHub has none.
    @ViewBuilder private var descriptionSection: some View {
        section(repository.summaryFromReadme == true ? "From the README" : translatedDescription == nil ? "Original description" : "Translated description",
                badge: translatedDescription == nil ? nil : "Translated on this Mac") {
            Text(translatedDescription ?? (repository.introduction == "No description was provided on GitHub Trending. Open the repository for details." ? ui(repository.introduction) : repository.introduction)).textSelection(.enabled)
            if translatedDescription != nil {
                DisclosureGroup(ui("Show original")) { Text(repository.summary).textSelection(.enabled).padding(.top, 8) }
                    .font(typography.body).accessibilityIdentifier("originalDescription")
            }
            if let translationMessage { Text(ui(translationMessage)).font(typography.metadata).foregroundStyle(.secondary) }
        }
    }
    /// A saved project's latest stable release; seen once the user leaves this project.
    @ViewBuilder private var releaseSection: some View {
        if let release {
            section("Latest release", badge: releaseIsNew ? "New" : nil) {
                HStack(spacing: 8) {
                    Text(release.tag).font(typography.listTitle)
                    if release.title != release.tag && !release.title.isEmpty { Text(release.title).foregroundStyle(.secondary).lineLimit(1) }
                    if let date = SnapshotDate.parse(release.updated) {
                        Text(date.formatted(.dateTime.year().month(.abbreviated).day().locale(locale))).foregroundStyle(.secondary)
                    }
                }
                if let url = URL(string: release.url) { Link(ui("Release notes on GitHub"), destination: url).font(typography.action) }
            }
            .onDisappear { if releaseIsNew { releaseSeen() } }
        }
    }

    /// How long the project has been on this daily list and its rank on each of the last seven days.
    @ViewBuilder private var trendHistorySection: some View {
        if let history, history.days.count >= 2, history.streak(repository.id) > 0 {
            let streak = history.streak(repository.id)
            section("Trending history") {
                Text(streak == 1 ? ui("New on today’s list") : String(format: ui("On today’s list %d days in a row"), streak))
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(history.recent(repository.id), id: \.date) { day in
                        VStack(spacing: 4) {
                            Text(day.rank.map { "#\($0)" } ?? "–").font(typography.listTitle).monospacedDigit()
                                .foregroundStyle(day.rank == nil ? .tertiary : .primary)
                            Text(TrendHistory.label(day.date, locale: locale)).font(typography.metadata).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                Text(ui("Rank on GitHub Trending each day (UTC). – means not on the list."))
                    .font(typography.metadata).foregroundStyle(.secondary)
            }
        }
    }

    /// The README excerpt from the shared feed, when GitHub's description is not the whole story.
    @ViewBuilder private var readmeExcerptSection: some View {
        if let excerpt = repository.readmeExcerpt {
            section("From the README", badge: translatedExcerpt == nil ? nil : "Translated on this Mac") {
                Text(translatedExcerpt ?? excerpt).textSelection(.enabled)
                if translatedExcerpt != nil {
                    DisclosureGroup(ui("Show original")) { Text(excerpt).textSelection(.enabled).padding(.top, 8) }
                        .font(typography.body)
                }
            }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.block) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(repository.owner + " /").font(typography.owner).foregroundStyle(.secondary)
                    Text(repository.name).font(typography.projectTitle).lineLimit(2).accessibilityAddTraits(.isHeader)
                    if repository.summaryAvailable { Text(translatedDescription ?? repository.summary).font(typography.body).lineSpacing(typography.bodyLeading) }
                }
                // One row of actions: the main two first, the rest in a menu.
                HStack(spacing: 8) {
                    Button(action: save) { Label(ui(saved ? "Unsave" : "Save"), systemImage: saved ? "bookmark.fill" : "bookmark") }
                        .buttonStyle(.borderedProminent).help(ui("Save / unsave (⌘D)"))
                        .accessibilityIdentifier("bookmarkButton")
                    Button(action: openSource) { Label(ui("Open on GitHub"), systemImage: "arrow.up.right") }.buttonStyle(.bordered)
                    Button(action: preview) { Label(ui("Preview README"), systemImage: "doc.text") }.buttonStyle(.bordered)
                        .accessibilityIdentifier("previewReadmeButton")
                    Menu {
                        Button(ui(reading.read ? "Mark unread" : "Mark read")) {
                            var item = reading; item.read.toggle(); updateReading(item)
                        }.accessibilityIdentifier("markReadButton")
                        Button(ui(reading.hidden ? "Unhide" : "Hide")) {
                            var item = reading; item.hidden.toggle(); updateReading(item)
                        }.accessibilityIdentifier("hideProjectButton")
                    } label: { Label(ui("More"), systemImage: "ellipsis") }
                        .labelStyle(.iconOnly).menuIndicator(.hidden).fixedSize().help(ui("More"))
                }.controlSize(.large).font(typography.action)
                Divider()
                HStack(spacing: 32) {
                    metric("Total stars", repository.stars?.formatted() ?? "Unknown")
                    metric(repository.gainLabel(for: feed), repository.gain(for: feed).map { "+" + $0.formatted() } ?? "Unknown")
                    metric("Language", repository.language)
                }
                Divider()
                descriptionSection
                readmeExcerptSection
                trendHistorySection
                releaseSection
                if !repository.features.isEmpty { section("Features") {
                    ForEach(repository.features, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 8) { Text(ui("•")); Text(feature) }
                    }
                }
                }
                if !repository.usage.isEmpty { section("Possible uses") {
                    HStack(spacing: 12) {
                        Rectangle().fill(.quaternary).frame(width: 2)
                        Text(repository.usage).textSelection(.enabled)
                    }.fixedSize(horizontal: false, vertical: true)
                }
                }
                if saved {
                    SavedProjectEditor(repositoryID: repository.id, reading: reading, update: updateReading)
                }
                DisclosureGroup(ui("Korean explanation · optional AI"), isExpanded: $showKorean) {
                  section("한국어 설명") {
                    if let summary {
                        Text(summary.text).textSelection(.enabled)
                        Text(ui("Generated: ") + summary.generatedAt.formatted(.dateTime.year().month(.abbreviated).day().hour().minute().locale(locale)))
                            .font(typography.metadata).foregroundStyle(.secondary)
                        Link(ui("Read the source README"), destination: summary.sourceURL).font(typography.action)
                        Text(ui("AI-generated from a README excerpt. Check the original for errors or missing details."))
                            .font(typography.metadata).foregroundStyle(.secondary)
                    } else {
                        Text(ui("Optional: generate a Korean explanation of the README on this Mac. Browsing original descriptions never needs AI."))
                    }
                    if let message = summaryMessage { Text(ui(message)).foregroundStyle(.secondary) }
                    if isSummarizing {
                        HStack { ProgressView().controlSize(.small); Button(ui("Cancel generation"), action: cancel) }
                    } else if let reason = OnDeviceSummary.unavailableReason {
                        Text(ui(reason)).foregroundStyle(.secondary)
                    } else {
                        Button(ui(summary == nil ? "Explain in Korean" : "Check README for changes"), action: summarize)
                            .buttonStyle(.bordered).accessibilityIdentifier("localSummaryButton")
                    }
                  }
                }.font(typography.section)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label(ui("Source: GitHub Trending"), systemImage: "info.circle")
                    Text(ui("Collected: ") + (repository.capturedAt.flatMap { SnapshotDate.display($0, locale: locale) } ?? ui("Unknown")))
                    Text(ui("Saved metrics reflect the snapshot at the time of saving."))
                }.font(typography.metadata).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28).padding(.vertical, 24).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }.background(Color(nsColor: .textBackgroundColor))
            .onChange(of: repository.id) { _, _ in showKorean = false }
    }
    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ui(label)).font(typography.metadata).foregroundStyle(.secondary)
            Text(ui(value)).font(typography.listTitle).monospacedDigit()
        }
    }
    private func section<Content: View>(_ title: String, badge: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(ui(title)).font(typography.section).accessibilityAddTraits(.isHeader)
                Spacer()
                if let badge { Text(ui(badge)).font(typography.metadata).foregroundStyle(.secondary) }
            }
            VStack(alignment: .leading, spacing: 6, content: content).font(typography.body).foregroundStyle(.primary).lineSpacing(typography.bodyLeading)
        }
    }
}

private struct SavedProjectEditor: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @Environment(\.appTypography) private var typography
    @ViewState<String> private var note = ""
    let repositoryID: String
    let reading: ProjectReading
    let update: (ProjectReading) -> Void
    private func ui(_ source: String) -> String { (InterfaceLanguage(rawValue: interfaceLanguage) ?? .english).text(source) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(ui("My project notes")).font(typography.section)
            Picker(ui("Status"), selection: Binding(get: { reading.stage }, set: { stage in
                var item = reading; item.stage = stage; update(item)
            })) {
                ForEach(ProjectStage.allCases) { Text(ui($0.rawValue)).tag($0) }
            }.accessibilityIdentifier("projectStage")
            TextEditor(text: $note).font(typography.body).frame(height: 100)
                .padding(5).overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                .accessibilityLabel(ui("Personal note")).accessibilityIdentifier("projectNote")
            Button(ui("Save note")) { var item = reading; item.note = note; update(item) }
                .disabled(note == reading.note).accessibilityIdentifier("saveProjectNote")
            Text(ui("Stored only on this Mac.")).font(typography.metadata).foregroundStyle(.secondary)
        }
        .onAppear { note = reading.note }
        .onChange(of: repositoryID) { _, _ in note = reading.note }
    }
}

private struct ReadmePreview: View {
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTypography) private var typography
    @ViewState<String> private var text = ""
    @ViewState<String?> private var failure: String?
    @ViewState<String?> private var note: String?
    /// Translations the main README links to; empty when it links none.
    @ViewState<[ReadmeVariant]> private var variants = []
    /// Path of the translation being shown; "" is the original README.
    @ViewState<String> private var selection = ""
    @ViewState<Bool> private var chosePreferred = false
    let repository: Repository
    private var language: InterfaceLanguage { InterfaceLanguage(rawValue: interfaceLanguage) ?? .english }
    private func ui(_ source: String) -> String { language.text(source) }
    private var reader: ReadmeReader { ReadmeReader(cache: .appHTML, format: .html) }
    private var selectedVariant: ReadmeVariant? { variants.first { $0.path == selection } }
    private func name(_ variant: ReadmeVariant) -> String {
        language.locale.localizedString(forIdentifier: variant.language)?.capitalized(with: language.locale) ?? variant.language
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(repository.fullName).font(typography.heading)
                Spacer()
                if !variants.isEmpty { languageMenu }
                Button(ui("Done")) { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text(ui(selection.isEmpty ? "Original README · rendered by GitHub · no AI" : "Translation by the project · may be older than the original"))
                .font(typography.metadata).foregroundStyle(.secondary)
            Divider()
            content
        }.padding(24).frame(width: 780, height: 660)
            .task(id: repository.id + "|" + selection) { await load() }
    }

    private var languageMenu: some View {
        Picker(ui("README language"), selection: $selection) {
            Text(ui("Original")).tag("")
            Divider()
            ForEach(variants) { variant in Text(name(variant)).tag(variant.path) }
        }
        .labelsHidden().fixedSize().help(ui("README language"))
        .accessibilityLabel(ui("README language"))
    }

    @ViewBuilder private var content: some View {
        if let failure {
            Text(ui(failure))
            if let url = repository.githubURL { Link(ui("Open on GitHub"), destination: url) }
        } else if text.isEmpty {
            ProgressView(ui("Loading README…")).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ReadmeWebView(html: text, repository: repository, fontSize: 15 * typography.size.scale, directory: selectedVariant?.directory ?? "")
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(ui(note ?? "Links open in your browser. Images load from GitHub."))
                .font(typography.metadata).foregroundStyle(.secondary)
        }
    }

    /// Loads the original first to find its translations, then opens the one in the app's language if there is one.
    private func load() async {
        text = ""; failure = nil
        do {
            if selection.isEmpty || variants.isEmpty {
                let original = try await reader.load(repository, maxAge: 6 * 3600)
                try Task.checkCancellation()
                if variants.isEmpty { variants = ReadmeVariant.find(in: original.text, repository: repository.fullName) }
                if !chosePreferred {
                    chosePreferred = true
                    let code = language.rawValue
                    if selection.isEmpty, let preferred = variants.first(where: { $0.language == code || $0.language.hasPrefix(code + "-") }) {
                        selection = preferred.path; return  // the task restarts for the translation
                    }
                }
                if selection.isEmpty { text = original.text; return }
            }
            let path = selection
            do {
                let document = try await reader.load(repository, path: path, maxAge: 6 * 3600)
                try Task.checkCancellation(); note = nil; text = document.text
            } catch ReadmeError.rateLimited {
                throw ReadmeError.rateLimited
            } catch where !Task.isCancelled {
                // A broken translation link: go back to the original and say why.
                note = "That translation could not be loaded. Showing the original."; selection = ""
            }
        } catch ReadmeError.rateLimited {
            failure = "GitHub’s hourly limit for README requests on this network was reached. Try again later. Browsing is not affected."
        } catch { if !Task.isCancelled { failure = "Could not load README. Check your connection or open the repository on GitHub." } }
    }
}

#if DEBUG
/// The README preview as DebugSnapshot shows it.
struct ReadmePreviewSnapshot: View {
    let repository: Repository
    var body: some View { ReadmePreview(repository: repository) }
}
#endif
