import Foundation

// Standalone checks for the saved-projects Markdown export.
@main
struct ExportChecks {
    static func main() {
        func repo(_ id: String, _ summary: String, stars: Int? = nil, language: String = "Swift") -> Repository {
            Repository(id: id, owner: String(id.split(separator: "/")[0]), language: language, summary: summary, introduction: summary,
                       features: [], usage: "", stars: stars, dailyGain: nil, weeklyGain: nil)
        }
        func reading(_ stage: ProjectStage, _ note: String = "") -> ProjectReading { var r = ProjectReading(); r.stage = stage; r.note = note; return r }
        let day = { (d: Int) in Date(timeIntervalSince1970: 1_793_750_400 + Double(d) * 86_400) }  // 2026-11-04 UTC + d days
        let entries = [
            SavedExport.Entry(repository: repo("a/later", "Line one\nline two [x]", stars: 12345), savedAt: day(0), reading: reading(.later)),
            SavedExport.Entry(repository: repo("b/use", "No description provided.", language: "Unknown"), savedAt: day(1), reading: reading(.using, "Great for CI.\nUse --fast")),
            SavedExport.Entry(repository: repo("c/later2", "Second"), savedAt: day(2), reading: reading(.later)),
        ]
        let md = SavedExport.markdown(entries, exportedAt: day(2), locale: Locale(identifier: "en_US"))
        let lines = md.components(separatedBy: "\n")
        precondition(lines[0] == "# GitMorning saved projects" && lines[2] == "Exported Nov 6, 2026 · 3 projects", md)
        // Groups in order In use, Testing (empty, skipped), Try later; newest saved first.
        let headings = lines.filter { $0.hasPrefix("## ") }
        precondition(headings == ["## In use (1)", "## Try later (2)"], "\(headings)")
        precondition(md.contains("- **[b/use](https://github.com/b/use)**\n  saved Nov 5, 2026\n  > Great for CI.\n  > Use --fast"), md)
        precondition(md.contains("- **[a/later](https://github.com/a/later)** — Line one line two \\[x\\]\n  Swift · ★ 12,345 · saved Nov 4, 2026"), md)
        precondition(md.range(of: "c/later2")!.lowerBound < md.range(of: "a/later")!.lowerBound)
        let korean = SavedExport.markdown(entries, exportedAt: day(2), locale: Locale(identifier: "ko_KR"),
                                          text: { ["In use": "사용 중", "saved %@": "%@ 보관"][$0] ?? $0 })
        precondition(korean.contains("## 사용 중 (1)") && korean.contains("2026년 11월 5일 보관"), korean)
        precondition(SavedExport.markdown([], exportedAt: day(0), locale: Locale(identifier: "en_US")).hasSuffix("· 0 projects\n"))
        print("PASS: saved export — status groups and order, links, escaping, notes as quotes, localized labels and dates")
    }
}
