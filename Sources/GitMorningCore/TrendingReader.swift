import Foundation

// A small structural reader for GitHub's public Trending HTML. Reject a changed
// or partial page rather than replacing the last valid snapshot with guesses.
public enum TrendingHTML {
    private final class Node {
        let tag: String
        let attributes: [String: String]
        var children: [Node] = []
        var content = ""
        init(_ tag: String, _ attributes: [String: String] = [:]) { self.tag = tag; self.attributes = attributes }
        var ignored: Bool {
            ["script", "style", "template", "dialog", "form"].contains(tag)
            || attributes["hidden"] != nil || attributes["aria-hidden"] == "true"
        }
        func nodes(_ tag: String? = nil) -> [Node] {
            children.filter { !$0.ignored }.flatMap { child in
                (tag == nil || child.tag == tag ? [child] : []) + child.nodes(tag)
            }
        }
        var text: String { ignored ? "" : content + children.map(\.text).joined(separator: " ") }
    }
    private static func matches(_ pattern: String, _ text: String) -> [NSTextCheckingResult] {
        (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]))?
            .matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
    }
    private static func group(_ match: NSTextCheckingResult, _ index: Int, _ text: String) -> String {
        Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
    }
    // Single left-to-right pass, like Python's html.unescape, so "&amp;lt;" stays "&lt;".
    // Semicolon-terminated named entities come from the generated HTML5 table.
    static func unescape(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = "", cursor = text.startIndex
        for match in matches("&(#x[0-9a-f]+|#[0-9]+|[a-z][a-z0-9]*);", text) {
            guard let range = Range(match.range, in: text) else { continue }
            let name = group(match, 1, text)
            let decoded: String?
            if name.hasPrefix("#") {
                let digits = name.dropFirst()
                let number = digits.lowercased().hasPrefix("x") ? UInt32(digits.dropFirst(), radix: 16) : UInt32(digits)
                decoded = String(number.flatMap { $0 == 0 ? nil : UnicodeScalar($0) } ?? "\u{FFFD}")
            } else { decoded = HTMLEntities.named[name] }
            guard let decoded else { continue }
            result += text[cursor..<range.lowerBound] + decoded
            cursor = range.upperBound
        }
        return result + text[cursor...]
    }
    private static func plain(_ text: String) -> String {
        unescape(text).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    // Digits with optional thousands separators; anything else is unknown (nil), never zero.
    static func count(_ text: String) -> Int? {
        let cleaned = text.filter { $0 != "," && !$0.isWhitespace }
        guard !cleaned.isEmpty, cleaned.allSatisfy({ ("0"..."9").contains($0) }) else { return nil }
        return Int(cleaned)
    }
    public static func url(for key: SnapshotKey) -> URL {
        URL(string: "https://github.com/trending" + (key.language == "all" ? "" : "/" + key.language.lowercased()) + "?since=" + key.period)!
    }
    public static func snapshot(_ html: String, key: SnapshotKey, now: Date = Date()) throws -> Data {
        guard html.utf8.count <= 3_000_000 else { throw SnapshotReadError.oversizedResponse }
        let root = Node("root")
        var stack = [root]
        let voidTags = Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"])
        // Quoted attribute values may contain ">"; a "<" that does not start a tag is text.
        for token in matches("<!--.*?-->|<![^>]*>|</?[a-z](?:\"[^\"]*\"|'[^']*'|[^'\">])*>|[^<]+|<", html) {
            let value = group(token, 0, html)
            if value.hasPrefix("<!") { continue }
            if value.hasPrefix("</") {
                let tag = value.dropFirst(2).prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" }).lowercased()
                if let index = stack.lastIndex(where: { $0.tag == tag }), index > 0 { stack.removeSubrange(index...) }
            } else if value.count > 1, value.hasPrefix("<") {
                let name = value.dropFirst().prefix(while: { $0.isLetter || $0.isNumber || $0 == "-" })
                let tag = name.lowercased()
                var attributes: [String: String] = [:]
                let rest = String(value.dropFirst(1 + name.count).dropLast())
                for attribute in matches("([^\\s\"'>/=]+)(?:\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'=<>`]+)))?", rest) {
                    let key = group(attribute, 1, rest).lowercased()
                    if attributes[key] == nil { attributes[key] = unescape((2...4).map { group(attribute, $0, rest) }.first { !$0.isEmpty } ?? "") }
                }
                let node = Node(tag, attributes)
                stack.last?.children.append(node)
                if !voidTags.contains(tag) && !value.hasSuffix("/>") {
                    guard stack.count < 128 else { throw SnapshotError.invalidSnapshot }; stack.append(node)
                }
            } else { let text = Node("#text"); text.content = value; stack.last?.children.append(text) }
        }
        let articles = root.nodes("article").filter { ($0.attributes["class"] ?? "").split(separator: " ").contains("Box-row") }
        guard !articles.isEmpty else { throw SnapshotError.invalidSnapshot }
        var rows: [[String: Any]] = []
        for article in articles {
            guard let href = article.nodes("h2").first?.nodes("a").first?.attributes["href"],
                  href.range(of: "^/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", options: .regularExpression) != nil else { throw SnapshotError.invalidRepository }
            let id = String(href.dropFirst()), parts = id.split(separator: "/")
            let stars = article.nodes("a").first { $0.attributes["href"] == href + "/stargazers" }.flatMap { count(plain($0.text)) }
            var growth: Int?
            let suffix = key.period == "daily" ? "today" : "this week"
            for span in article.nodes("span") {
                let text = plain(span.text)
                if let match = matches("^([0-9, ]+) stars? " + suffix + "$", text).first { growth = count(group(match, 1, text)); break }
            }
            rows.append(["id": id, "owner": String(parts[0]), "name": String(parts[1]), "url": "https://github.com/" + id,
                         "rank": rows.count + 1, "description": article.nodes("p").first.map { plain($0.text) } ?? "",
                         "language": article.nodes().first { $0.attributes["itemprop"] == "programmingLanguage" }.map { plain($0.text) } as Any? ?? NSNull(),
                         "stars": stars as Any? ?? NSNull(), "periodStars": growth as Any? ?? NSNull(), "summaryStatus": "pending"])
        }
        let payload: [String: Any] = ["schemaVersion": 1, "period": key.period, "languageFilter": key.language, "sourceURL": url(for: key).absoluteString,
                                      "collectedAt": ISO8601DateFormatter().string(from: now), "status": "complete", "repositories": rows]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        _ = try key.decode(data)
        return data
    }
}

public actor TrendingReader {
    public init() {}
    public func load(_ key: SnapshotKey) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: TrendingRedirects(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: TrendingHTML.url(for: key))
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("GitMorning (macOS Trending reader)", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { throw SnapshotReadError.invalidHTTPResponse }
        guard response.expectedContentLength <= 3_000_000 else { throw SnapshotReadError.oversizedResponse }
        var data = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard data.count < 3_000_000 else { throw SnapshotReadError.oversizedResponse }
            data.append(byte)
        }
        guard let html = String(data: data, encoding: .utf8) else { throw SnapshotError.invalidSnapshot }
        return try TrendingHTML.snapshot(html, key: key)
    }
}
private final class TrendingRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
