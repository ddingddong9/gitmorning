import Foundation

/// Languages and keywords the user cares about. Matching projects come first in the
/// morning brief and are marked; the main list can filter to them.
public struct Interests: Equatable, Sendable {
    public private(set) var languages: [String]
    public private(set) var keywords: [String]

    /// Languages offered in Settings (GitHub's names, as Trending shows them).
    public static let languageChoices = ["Python", "TypeScript", "JavaScript", "Swift", "Go", "Rust", "Java", "Kotlin",
                                         "C++", "C", "C#", "Ruby", "PHP", "Shell", "Dart", "Zig"]

    public init(languages: [String] = [], keywords: [String] = []) {
        self.languages = Self.clean(languages, minLength: 1)
        self.keywords = Self.clean(keywords, minLength: 2)
    }

    /// From the comma-separated strings kept in UserDefaults.
    public init(storedLanguages: String, storedKeywords: String) {
        self.init(languages: Self.split(storedLanguages), keywords: Self.split(storedKeywords))
    }
    public var storedLanguages: String { languages.joined(separator: ",") }
    public var storedKeywords: String { keywords.joined(separator: ", ") }
    public var isEmpty: Bool { languages.isEmpty && keywords.isEmpty }
    /// Changes whenever the interests change, to tell whether a brief was built with the current ones.
    public var signature: String { storedLanguages + "|" + keywords.map { $0.lowercased() }.joined(separator: ",") }

    /// What matched: the project's language, or the first keyword found in its name, description, or README excerpt.
    public func match(language: String?, texts: [String]) -> String? {
        if let language, let hit = languages.first(where: { $0.caseInsensitiveCompare(language) == .orderedSame }) { return hit }
        return keywords.first { keyword in texts.contains { Self.contains($0, keyword) } }
    }

    /// Whole-word match for Latin keywords ("ai" does not match "maintain"); plain substring for other scripts.
    static func contains(_ text: String, _ keyword: String) -> Bool {
        if keyword.unicodeScalars.allSatisfy({ $0.isASCII }) {
            let pattern = "(?<![A-Za-z0-9])" + NSRegularExpression.escapedPattern(for: keyword) + "(?![A-Za-z0-9])"
            return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        return text.localizedCaseInsensitiveContains(keyword)
    }

    private static func split(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n"))
    }
    private static func clean(_ values: [String], minLength: Int) -> [String] {
        var seen = Set<String>(), result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= minLength, trimmed.count <= 40, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
            if result.count == 20 { break }
        }
        return result
    }
}
