import Foundation

/// Saved projects as a Markdown document, grouped by status (In use, Testing, Try later),
/// for a blog post, a note, or a backup.
public enum SavedExport {
    public struct Entry {
        public let repository: Repository
        public let savedAt: Date
        public let reading: ProjectReading
        public init(repository: Repository, savedAt: Date, reading: ProjectReading) {
            self.repository = repository; self.savedAt = savedAt; self.reading = reading
        }
    }

    /// - Parameters:
    ///   - text: translates the fixed English labels into the interface language.
    ///   - locale: formats dates and numbers.
    public static func markdown(_ entries: [Entry], exportedAt: Date, locale: Locale, text: (String) -> String = { $0 }) -> String {
        let day = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        var lines = ["# " + text("GitMorning saved projects"), "",
                     String(format: text("Exported %@ · %d projects"), exportedAt.formatted(day), entries.count)]
        for stage in [ProjectStage.using, .testing, .later] {
            let group = entries.filter { $0.reading.stage == stage }.sorted { $0.savedAt > $1.savedAt }
            guard !group.isEmpty else { continue }
            lines += ["", "## \(text(stage.rawValue)) (\(group.count))", ""]
            for entry in group {
                let repo = entry.repository
                let link = repo.githubURL.map { "[\(escape(repo.fullName))](\($0.absoluteString))" } ?? escape(repo.fullName)
                let summary = oneLine(repo.summary)
                lines.append("- **\(link)**" + (summary.isEmpty || summary == "No description provided." ? "" : " — " + escape(summary)))
                var facts: [String] = []
                if repo.language != "Unknown" { facts.append(repo.language) }
                if let stars = repo.stars { facts.append("★ " + stars.formatted(.number.locale(locale))) }
                facts.append(String(format: text("saved %@"), entry.savedAt.formatted(day)))
                lines.append("  " + facts.joined(separator: " · "))
                let note = entry.reading.note.trimmingCharacters(in: .whitespacesAndNewlines)
                if !note.isEmpty {
                    lines += note.components(separatedBy: .newlines).map { "  > " + $0 }
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
    }
    /// Keeps project text from turning into links, emphasis, or HTML.
    private static func escape(_ text: String) -> String {
        var result = ""
        for character in text {
            if "\\`*_[]<>#|".contains(character) { result.append("\\") }
            result.append(character)
        }
        return result
    }
}
