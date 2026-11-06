import Foundation

@main
struct ContractChecks {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let snapshot = try TrendSnapshot.decode(data)
        precondition(snapshot.repositories.count == 2)
        precondition(snapshot.repositories[0].id == "example/alpha")
        precondition(snapshot.repositories[1].language == nil)
        precondition(snapshot.repositories[0].periodStars == 1234)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object["schemaVersion"] = 999
        var rejected = false
        do { _ = try TrendSnapshot.decode(JSONSerialization.data(withJSONObject: object)) } catch { rejected = true }
        precondition(rejected)
        object["schemaVersion"] = 1
        object["sourceURL"] = "https://evil.example/feed"
        rejected = false
        do { _ = try TrendSnapshot.decode(JSONSerialization.data(withJSONObject: object)) } catch { rejected = true }
        precondition(rejected)
        print("PASS: Python → Swift snapshot contract, null metrics, unsupported versions, invalid origins")
    }
}
