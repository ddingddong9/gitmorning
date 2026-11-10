import SwiftUI
import GitMorningCore

/// Menu bar popover: today's brief at a glance, one click to open a project.
struct MorningBriefMenu: View {
    let model: MorningBriefModel
    let state: AppState
    @AppStorage("interfaceLanguage") private var interfaceLanguage = "en"
    @AppStorage("autoTranslateDescriptions") private var autoTranslateDescriptions = true
    @AppStorage("interestLanguages") private var interestLanguages = ""
    @AppStorage("interestKeywords") private var interestKeywords = ""
    @Environment(\.openWindow) private var openWindow
    @Environment(\.appTypography) private var typography
    private static let translations = DescriptionTranslationStorage(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GitMorning/description-translations-v1"))
    /// Reuse a translation the main window already saved; never translate from the menu.
    private func description(_ item: MorningBrief.Item) -> String {
        guard autoTranslateDescriptions, !item.description.isEmpty,
              let saved = try? Self.translations.load(repositoryID: item.id, original: item.description, target: interfaceLanguage) else { return item.description }
        return saved.text
    }
    private var language: InterfaceLanguage { InterfaceLanguage(rawValue: interfaceLanguage) ?? .english }
    private func ui(_ source: String) -> String { language.text(source) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
            Divider()
            content.frame(maxHeight: 380)
            Divider()
            footer.padding(.horizontal, 10).padding(.vertical, 8)
        }
        .frame(width: 360)
        .task { if model.brief == nil { await model.generate() } else { model.applyInterests() } }
        .onChange(of: interestLanguages + "|" + interestKeywords) { _, _ in model.applyInterests() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Label(ui("Morning brief"), systemImage: "sun.horizon").font(typography.listTitle)
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
            }
            if let brief = model.brief {
                Text(model.headline(brief, language: language)).font(typography.listBody)
                Text(ui(brief.isFirst ? "First brief · nothing to compare yet" : "Since yesterday’s brief") + " · "
                     + brief.generatedAt.formatted(.dateTime.month().day().hour().minute().locale(language.locale)))
                    .font(typography.metadata).foregroundStyle(.secondary)
            }
            if let problem = model.problem { Text(ui(problem)).font(typography.metadata).foregroundStyle(.orange) }
        }
    }

    @ViewBuilder private var content: some View {
        if let brief = model.brief, !brief.items.isEmpty {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(brief.items) { item in
                        Button { open(item.id) } label: { row(item) }.buttonStyle(.plain)
                            .accessibilityIdentifier("briefItem-" + item.id)
                    }
                }.padding(6)
            }
        } else {
            Text(ui(model.brief == nil ? (model.isLoading ? "Getting today’s brief…" : "No brief yet") : "Nothing new or rising today."))
                .font(typography.listBody).foregroundStyle(.secondary).padding(14).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ item: MorningBrief.Item) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(item.rank)").font(typography.metadata).monospacedDigit().foregroundStyle(.secondary).frame(width: 20, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.id).font(typography.listTitle).lineLimit(1).truncationMode(.middle)
                    switch item.change {
                    case .new: Text(ui("New")).font(typography.metadata).bold().foregroundStyle(.green)
                    case .rising(let delta): Text("↑\(delta)").font(typography.metadata).bold().foregroundStyle(.green)
                    case .unchanged: EmptyView()
                    }
                }
                let text = description(item)
                if !text.isEmpty { Text(text).font(typography.listBody).foregroundStyle(.secondary).lineLimit(2).lineSpacing(typography.listLeading) }
                HStack(spacing: 10) {
                    if let interest = item.interest {
                        Label(interest, systemImage: "star.fill").foregroundStyle(.orange).help(ui("Matches your interests"))
                    }
                    if let language = item.language, language != item.interest { Text(language) }
                    if let gain = item.periodStars { Text("+\(gain.formatted())").monospacedDigit() }
                }.font(typography.metadata).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .contentShape(Rectangle())
        .help(ui("Open in GitMorning"))
    }

    private var footer: some View {
        HStack {
            Button(ui("Update brief")) { Task { await model.generate() } }.disabled(model.isLoading)
            Spacer()
            Button(ui("Open GitMorning")) { open(nil) }.keyboardShortcut(.defaultAction)
            Menu {
                Toggle(ui("Open GitMorning at login"), isOn: Binding(get: { LoginItem.isEnabled }, set: { _ = LoginItem.set($0) }))
                SettingsLink { Text(ui("Settings")) }
                Divider()
                Button(ui("Quit GitMorning")) { NSApp.terminate(nil) }
            } label: { Label(ui("More"), systemImage: "ellipsis.circle") }
                .labelStyle(.iconOnly).menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        }
        .controlSize(.regular).font(typography.action)
    }

    private func open(_ id: String?) {
        if let id { state.reveal(id) }
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
