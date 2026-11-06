import Foundation

/// Another-language README that a project links from its main README,
/// such as `README.ko.md`, `README_EN.md`, or `readme_i18n/README_ko_KR.md`.
public struct ReadmeVariant: Equatable, Hashable, Sendable, Identifiable {
    /// Path inside the repository, without a leading slash.
    public let path: String
    /// Language tag such as `ko`, `en`, `zh-CN`, `pt-BR`.
    public let language: String
    public var id: String { path }

    public init(path: String, language: String) { self.path = path; self.language = language }

    /// The folder of `path`, with a trailing slash ("" at the repository root), for resolving relative images.
    public var directory: String {
        guard let slash = path.lastIndex(of: "/") else { return "" }
        return String(path[...slash])
    }

    /// Common README translation languages. A short list avoids reading `README_OLD.md` or `README_V2.md` as languages.
    static let languages: Set<String> = ["en", "ko", "ja", "zh", "es", "fr", "de", "pt", "ru", "vi", "tr", "it", "ar", "th", "id",
                                          "uk", "pl", "nl", "hi", "fa", "he", "cs", "sv", "da", "fi", "nb", "el", "hu", "ro", "ms",
                                          "bn", "ur", "ta", "ca", "bg", "sk", "sr", "hr", "lt", "lv", "et", "sl", "fil", "tl"]
    static let aliases: [String: String] = ["cn": "zh-CN", "zh-cn": "zh-CN", "zh-hans": "zh-CN", "zh-sg": "zh-CN", "zh": "zh-CN",
                                             "zh-tw": "zh-TW", "zh-hant": "zh-TW", "zh-hk": "zh-HK", "tw": "zh-TW",
                                             "jp": "ja", "kr": "ko", "kor": "ko", "eng": "en", "vn": "vi", "ua": "uk",
                                             "gr": "el", "cz": "cs", "br": "pt-BR", "pt-br": "pt-BR", "pt-pt": "pt", "no": "nb", "tl": "fil"]
    /// Link text used in language bars, for files whose names do not say the language.
    static let names: [String: String] = ["english": "en", "한국어": "ko", "日本語": "ja", "简体中文": "zh-CN", "中文": "zh-CN",
                                           "繁體中文": "zh-TW", "繁体中文": "zh-TW", "español": "es", "français": "fr", "deutsch": "de",
                                           "português": "pt", "русский": "ru", "tiếng việt": "vi", "türkçe": "tr", "italiano": "it",
                                           "العربية": "ar", "ไทย": "th", "bahasa indonesia": "id", "українська": "uk", "polski": "pl"]

    /// A language tag from a code found in a file or folder name, or nil when it is not a known language.
    public static func language(code raw: String) -> String? {
        let code = raw.replacingOccurrences(of: "_", with: "-").lowercased()
        if let alias = aliases[code] { return alias }
        let parts = code.split(separator: "-").map(String.init)
        guard let base = parts.first, languages.contains(base), parts.count <= 2 else { return nil }
        if base == "zh", parts.count == 2 { return aliases["zh-" + parts[1]] ?? "zh-CN" }
        if base == "pt", parts.count == 2, parts[1] == "br" { return "pt-BR" }
        return aliases[base] ?? base
    }

    /// Translations linked from GitHub-rendered README HTML. Keeps the first link for each language and
    /// leaves out the README being shown (`current`) and anything outside this repository.
    public static func find(in html: String, repository: String, current: String = "README.md") -> [ReadmeVariant] {
        let anchor = try! NSRegularExpression(pattern: "<a\\b[^>]*?href=\"([^\"]+)\"[^>]*>(.*?)</a>", options: [.caseInsensitive, .dotMatchesLineSeparators])
        let source = html as NSString
        var found: [ReadmeVariant] = [], languages = Set<String>()
        for match in anchor.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            guard let path = repositoryPath(unescape(source.substring(with: match.range(at: 1))), repository: repository),
                  path.lowercased() != current.lowercased() else { continue }
            let text = unescape(source.substring(with: match.range(at: 2)).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
            guard let language = language(path: path, linkText: text), languages.insert(language).inserted else { continue }
            found.append(ReadmeVariant(path: path, language: language))
        }
        return found
    }

    /// The README language of a path: `README.ko.md`, `README_zh-CN.md`, `docs/ko/README.md`, or a readme-like file named by its link text.
    static func language(path: String, linkText: String) -> String? {
        let parts = path.split(separator: "/").map(String.init)
        guard let file = parts.last, file.range(of: "\\.(md|markdown|mdx|rst|txt)$", options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        let stem = file.replacingOccurrences(of: "\\.[^.]+$", with: "", options: .regularExpression)
        if let range = stem.range(of: "^readme[._-]?(.+)$", options: [.regularExpression, .caseInsensitive]) {
            let code = String(stem[range]).dropFirst(6).trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
            if let language = language(code: code) { return language }
        } else if stem.caseInsensitiveCompare("readme") == .orderedSame, parts.count >= 2, let language = language(code: parts[parts.count - 2]) {
            return language  // docs/ko/README.md
        }
        guard path.lowercased().contains("readme") else { return nil }
        let name = linkText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            .replacingOccurrences(of: "^[^\\p{L}]+", with: "", options: .regularExpression)  // drop flags and symbols
        return names[name]
    }

    /// A link's path inside `repository`, from a relative link or a github.com blob URL. Nil for anything else.
    static func repositoryPath(_ href: String, repository: String) -> String? {
        let link = href.components(separatedBy: "#")[0].components(separatedBy: "?")[0]
        guard !link.isEmpty else { return nil }
        var path: String
        if let url = URL(string: link), let scheme = url.scheme {
            guard scheme == "https" || scheme == "http", url.host?.lowercased() == "github.com" else { return nil }
            let parts = url.path.split(separator: "/").map(String.init)
            // /owner/name/blob/<ref>/path…
            guard parts.count >= 5, (parts[0] + "/" + parts[1]).lowercased() == repository.lowercased(), parts[2] == "blob" else { return nil }
            path = parts[4...].joined(separator: "/")
        } else {
            guard !link.hasPrefix("//"), !link.contains(":") else { return nil }
            path = link
        }
        path = path.removingPercentEncoding ?? path
        var segments: [String] = []
        for segment in path.split(separator: "/").map(String.init) {
            switch segment {
            case ".", "": continue
            case "..": guard !segments.isEmpty else { return nil }; segments.removeLast()
            default: segments.append(segment)
            }
        }
        return segments.isEmpty ? nil : segments.joined(separator: "/")
    }

    private static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">")
    }
}
