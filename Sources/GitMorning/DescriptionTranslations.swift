import SwiftUI
import Observation
import NaturalLanguage
import Translation
import GitMorningCore

struct DescriptionTranslationGroup {
    let source: String
    let repositories: [Repository]
}

@MainActor @Observable
final class DescriptionTranslations {
    private(set) var items: [String: DescriptionTranslation] = [:]
    private(set) var messages: [String: String] = [:]
    private(set) var pending = Set<String>()
    private var runID = UUID()
    private let storage: DescriptionTranslationStorage
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("GitMorning/description-translations-v1")
        storage = DescriptionTranslationStorage(directory: base)
    }
    static func key(_ repository: Repository, target: String) -> String {
        DescriptionTranslation.key(repositoryID: repository.id, original: repository.summary, target: target)
    }
    static func inputID(_ repositories: [Repository], target: String) -> String {
        LocalSummary.hash(repositories.map { key($0, target: target) }.joined(separator: "|"))
    }
    func translation(_ repository: Repository, target: String) -> String? { items[Self.key(repository, target: target)]?.text }
    func message(_ repository: Repository, target: String) -> String? { messages[Self.key(repository, target: target)] }
    var isWorking: Bool { !pending.isEmpty }
    var hasFailures: Bool { !messages.isEmpty && pending.isEmpty }
    func isCurrent(_ id: UUID) -> Bool { runID == id }
    func prepare(_ repositories: [Repository], target: String, id: UUID) -> [DescriptionTranslationGroup] {
        runID = id; pending = []; messages = [:]
        var groups: [String: [Repository]] = [:]
        for repo in repositories {
            guard !repo.summary.isEmpty, repo.summary != "No description provided." else { continue }
            let key = Self.key(repo, target: target)
            if items[key] == nil { items[key] = try? storage.load(repositoryID: repo.id, original: repo.summary, target: target) }
            if items[key] != nil { continue }
            let recognizer = NLLanguageRecognizer(); recognizer.processString(repo.summary)
            guard let source = recognizer.dominantLanguage?.rawValue, source != "und" else {
                messages[key] = "Could not identify the description language. Showing the original."; continue
            }
            if Locale.Language(identifier: source).languageCode == Locale.Language(identifier: target).languageCode { continue }
            groups[source, default: []].append(repo); pending.insert(key)
        }
        // Process one source-language group at a time. A translation session must
        // never mix languages; download prompts are consequently serialized too.
        return groups.keys.sorted().map { DescriptionTranslationGroup(source: $0, repositories: groups[$0]!) }
    }
    func finish(_ repo: Repository, target: String, id: UUID, result: DescriptionTranslation?, error: String? = nil) {
        guard isCurrent(id) else { return }
        let key = Self.key(repo, target: target)
        pending.remove(key)
        if let result {
            items[key] = result
            do { try storage.save(result); messages[key] = nil }
            catch { messages[key] = "Translated, but the result could not be saved on this Mac." }
        } else { messages[key] = error }
    }
    func end(_ id: UUID) { if isCurrent(id) { pending = []; runID = UUID() } }
}

@available(macOS 15.0, *)
struct DescriptionTranslationDriver: View {
    let repositories: [Repository]
    let target: String
    let translations: DescriptionTranslations
    @ViewState<UUID> private var runID = UUID()
    @ViewState<[DescriptionTranslationGroup]> private var groups = []
    @ViewState<Int> private var index = 0
    @ViewState<TranslationSession.Configuration?> private var configuration = nil

    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .task {
                let planned = translations.prepare(repositories, target: target, id: runID)
                var supported: [DescriptionTranslationGroup] = []
                for group in planned {
                    let availability = LanguageAvailability()
                    let status = await availability.status(from: Locale.Language(identifier: group.source), to: Locale.Language(identifier: target))
                    guard !Task.isCancelled, translations.isCurrent(runID) else { return }
                    if status == .unsupported {
                        for repo in group.repositories { translations.finish(repo, target: target, id: runID, result: nil, error: "Translation is unavailable for this language. Showing the original.") }
                    } else { supported.append(group) }
                }
                groups = supported
                if let first = groups.first { configuration = makeConfiguration(source: first.source) }
            }
            .translationTask(configuration) { session in
                guard index < groups.count else { return }
                let group = groups[index], id = runID
                // Commit each successful item independently so a later failure
                // cannot throw away already translated descriptions.
                for repo in group.repositories {
                    guard !Task.isCancelled, translations.isCurrent(id) else { return }
                    do {
                        let response = try await session.translate(repo.summary)
                        try Task.checkCancellation()
                        let text = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty,
                              response.targetLanguage.languageCode == Locale.Language(identifier: target).languageCode else { throw ReadmeError.invalidText }
                        let item = DescriptionTranslation(repositoryID: repo.id, original: repo.summary, target: target, source: response.sourceLanguage.minimalIdentifier, text: text)
                        translations.finish(repo, target: target, id: id, result: item)
                    } catch {
                        guard !Task.isCancelled, translations.isCurrent(id) else { return }
                        // A denied download or model failure should not trigger
                        // repeated system prompts for every item in this group.
                        for remaining in group.repositories {
                            if translations.translation(remaining, target: target) == nil {
                                translations.finish(remaining, target: target, id: id, result: nil, error: "Translation could not complete. Showing the original. You can retry after downloading the languages.")
                            }
                        }
                        break
                    }
                }
                guard !Task.isCancelled, translations.isCurrent(id) else { return }
                index += 1
                configuration = index < groups.count ? makeConfiguration(source: groups[index].source) : nil
            }
            .onDisappear { translations.end(runID) }
    }
    private func makeConfiguration(source: String) -> TranslationSession.Configuration {
        if #available(macOS 26.4, *) {
            // The traditional translation model does not require Apple Intelligence.
            return .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target), preferredStrategy: .lowLatency)
        }
        return .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
    }
}
