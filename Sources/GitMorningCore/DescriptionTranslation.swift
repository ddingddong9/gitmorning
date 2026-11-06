import Foundation

/// The original description and target language are part of the identity. A
/// changed description or language can never reuse an unrelated translation.
public struct DescriptionTranslation: Codable, Equatable {
    public static let engineVersion = "apple-translation-v1"
    public let repositoryID: String
    public let original: String
    public let target: String
    public let source: String
    public let text: String
    public let version: String
    public init(repositoryID: String, original: String, target: String, source: String, text: String) {
        self.repositoryID = repositoryID; self.original = original; self.target = target
        self.source = source; self.text = text; version = Self.engineVersion
    }
    public static func key(repositoryID: String, original: String, target: String) -> String {
        // Length-delimited JSON prevents ambiguous concatenations.
        let encoded = try! JSONEncoder().encode([engineVersion, repositoryID, original, target])
        return LocalSummary.hash(String(decoding: encoded, as: UTF8.self))
    }
}
public struct DescriptionTranslationStorage {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    private func url(repositoryID: String, original: String, target: String) -> URL {
        directory.appendingPathComponent(DescriptionTranslation.key(repositoryID: repositoryID, original: original, target: target) + ".json")
    }
    public func load(repositoryID: String, original: String, target: String) throws -> DescriptionTranslation? {
        let path = url(repositoryID: repositoryID, original: original, target: target)
        guard FileManager.default.fileExists(atPath: path.path) else { return nil }
        let item = try JSONDecoder().decode(DescriptionTranslation.self, from: Data(contentsOf: path))
        guard item.version == DescriptionTranslation.engineVersion, item.repositoryID == repositoryID,
              item.original == original, item.target == target, !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return item
    }
    public func save(_ item: DescriptionTranslation) throws {
        guard ["en", "ko"].contains(item.target), !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ReadmeError.invalidText }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(item).write(to: url(repositoryID: item.repositoryID, original: item.original, target: item.target), options: .atomic)
    }
}
