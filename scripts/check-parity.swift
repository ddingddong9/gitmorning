import Foundation

// Keeps the app's Trending parser identical to pipeline/collect.py.
//
//   check-parity                                  Check every shared fixture in pipeline/tests/fixtures/parity.
//   check-parity <page.html> <period> <snapshot.json>
//                                                 Compare against a snapshot the Python collector wrote for the same page.
//
// Fixture names: <case>.<daily|weekly>.html expects <case>.<period>.json;
// <case>.<period>.reject.html must be rejected by both parsers.
@main struct ParityChecks {
    static func rows(_ html: String, period: String) throws -> NSArray {
        let data = try TrendingHTML.snapshot(html, key: SnapshotKey(period: period, language: "all"))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (object?["repositories"] as? NSArray) ?? []
    }

    static func describe(_ value: Any) -> String {
        (try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])).flatMap { String(data: $0, encoding: .utf8) } ?? "\(value)"
    }

    static func main() throws {
        let arguments = CommandLine.arguments
        if arguments.count == 4 {
            let html = try String(contentsOfFile: arguments[1], encoding: .utf8)
            let python = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: arguments[3]))) as? [String: Any]
            let expected = (python?["repositories"] as? NSArray) ?? []
            let actual = try rows(html, period: arguments[2])
            guard actual.isEqual(expected) else {
                print("FAIL: Swift and Python parsed \(arguments[1]) differently\nSwift:\n\(describe(actual))\nPython:\n\(describe(expected))")
                exit(1)
            }
            print("PASS: \(arguments[2]) page parsed identically by Swift and Python (\(actual.count) rows)")
            return
        }

        let directory = URL(fileURLWithPath: "pipeline/tests/fixtures/parity")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "html" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        precondition(!files.isEmpty, "No parity fixtures found; run from the repository root")
        var failures: [String] = []
        for file in files {
            let parts = file.lastPathComponent.split(separator: ".")
            let period = String(parts[1]), rejects = parts.contains("reject")
            let html = try String(contentsOf: file, encoding: .utf8)
            do {
                let actual = try rows(html, period: period)
                if rejects { failures.append("\(file.lastPathComponent): accepted, expected rejection"); continue }
                let expectedURL = file.deletingPathExtension().appendingPathExtension("json")
                let expected = try JSONSerialization.jsonObject(with: Data(contentsOf: expectedURL)) as? NSArray ?? []
                if !actual.isEqual(expected) { failures.append("\(file.lastPathComponent):\n\(describe(actual))\nexpected:\n\(describe(expected))") }
            } catch {
                if !rejects { failures.append("\(file.lastPathComponent): rejected (\(error)), expected rows") }
            }
        }
        guard failures.isEmpty else { print("FAIL:\n" + failures.joined(separator: "\n")); exit(1) }
        print("PASS: \(files.count) shared Trending fixtures parsed as pinned (entities, hidden, attributes, metrics, rejection)")
    }
}
