import Foundation

// Standalone checks for interests and interest-first morning briefs.
@main
struct InterestChecks {
    static func main() throws {
        let interests = Interests(storedLanguages: "Swift, rust,Swift", storedKeywords: "agent, ai,  데이터 , x, agent")
        precondition(interests.languages == ["Swift", "rust"] && interests.keywords == ["agent", "ai", "데이터"], "\(interests)")
        precondition(Interests(storedLanguages: interests.storedLanguages, storedKeywords: interests.storedKeywords) == interests)
        precondition(interests.match(language: "Rust", texts: []) == "rust")
        precondition(interests.match(language: "Go", texts: ["Coding Agent for teams"]) == "agent")
        precondition(interests.match(language: "Go", texts: ["maintain the domain"]) == nil, "whole words only for Latin keywords")
        precondition(interests.match(language: nil, texts: ["AI-powered"]) == "ai")
        precondition(interests.match(language: nil, texts: ["데이터베이스 도구"]) == "데이터")
        precondition(Interests().isEmpty && Interests().match(language: "Swift", texts: ["agent"]) == nil)

        func repo(_ n: Int, _ id: String, _ language: String?, _ description: String) -> [String: Any] {
            ["id": id, "owner": String(id.split(separator: "/")[0]), "name": String(id.split(separator: "/")[1]), "url": "https://github.com/" + id,
             "rank": n, "description": description, "language": language as Any? ?? NSNull(), "stars": 1, "periodStars": 1, "summaryStatus": "pending"]
        }
        var repos = (1...12).map { repo($0, "o/r\($0)", "Go", "Tool \($0)") }
        repos[10] = repo(11, "o/swifty", "Swift", "A Swift thing")
        repos[11] = repo(12, "o/agentic", "Python", "Runs an agent loop")
        let json = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "period": "daily", "languageFilter": "all",
            "sourceURL": "https://github.com/trending?since=daily", "collectedAt": "2026-11-06T00:00:00Z", "status": "complete", "repositories": repos])
        let snapshot = try TrendSnapshot.decode(json)
        let plain = MorningBrief.build(from: snapshot, day: "2026-11-06", now: Date(), earlier: nil)
        precondition(plain.items.map(\.rank) == Array(1...10) && plain.items.allSatisfy { $0.interest == nil })
        let mine = MorningBrief.build(from: snapshot, day: "2026-11-06", now: Date(), earlier: nil, interests: interests)
        precondition(mine.items.prefix(2).map(\.id) == ["o/swifty", "o/agentic"], "\(mine.items.map(\.id))")
        precondition(mine.items.prefix(2).map(\.interest) == ["Swift", "agent"] && mine.items.count == 10 && mine.items[2].rank == 1)
        precondition(mine.interestSignature == interests.signature && plain.interestSignature != mine.interestSignature)
        // Briefs saved before interests existed still decode.
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(plain)) as! [String: Any]
        old.removeValue(forKey: "interestSignature")
        let decodedOld = try JSONDecoder().decode(MorningBrief.self, from: JSONSerialization.data(withJSONObject: old))
        precondition(decodedOld.interestSignature == nil)
        print("PASS: interests — stored form, language and whole-word keyword matches, interest-first brief, older briefs decode")
    }
}
