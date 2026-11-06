import Foundation

// Validate a published feed with the app's own decoder.
//
//   check-feed <directory or https base URL> [max age in hours]
//
// Every period/language file must decode for its key. With a max age, every file
// must also be at most that old, which catches a stopped collector.
@main struct FeedChecks {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else { print("usage: check-feed <directory|https base> [max age hours]"); exit(2) }
        let base = arguments[1]
        let maxAge = arguments.count > 2 ? Double(arguments[2]).map { $0 * 3600 } : nil
        var failures: [String] = [], checked = 0
        for period in ["daily", "weekly"] {
            for language in ["all", "Python", "TypeScript", "JavaScript", "Swift", "Go", "Rust"] {
                let key = try SnapshotKey(period: period, language: language)
                do {
                    let data: Data
                    if base.hasPrefix("https://") {
                        data = try await SnapshotHTTPReader().load(key, endpoint: FeedEndpoint(base))
                    } else {
                        data = try Data(contentsOf: URL(fileURLWithPath: base).appendingPathComponent(key.filename))
                    }
                    let snapshot = try key.decode(data)
                    if let maxAge, let date = snapshot.collectedDate, Date().timeIntervalSince(date) > maxAge {
                        failures.append("\(key.filename): collected \(snapshot.collectedAt), older than \(Int(maxAge / 3600))h")
                    }
                    checked += 1
                } catch {
                    failures.append("\(key.filename): \(error)")
                }
            }
        }
        guard failures.isEmpty else { print("FAIL: feed \(base)\n" + failures.joined(separator: "\n")); exit(1) }
        print("PASS: \(checked) feed files decode with the app contract" + (maxAge.map { " and are newer than \(Int($0 / 3600))h" } ?? ""))
    }
}
