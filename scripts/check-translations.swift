import Foundation

@main struct TranslationChecks {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storage = DescriptionTranslationStorage(directory: directory)
        let item = DescriptionTranslation(repositoryID: "owner/repo", original: "A useful developer tool.", target: "ko", source: "en", text: "유용한 개발 도구입니다.")
        let absent = try storage.load(repositoryID: item.repositoryID, original: item.original, target: item.target)
        precondition(absent == nil)
        try storage.save(item)
        let restored = try storage.load(repositoryID: item.repositoryID, original: item.original, target: "ko")
        precondition(restored == item)
        let changed = try storage.load(repositoryID: item.repositoryID, original: "A changed description.", target: "ko")
        let english = try storage.load(repositoryID: item.repositoryID, original: item.original, target: "en")
        let another = try storage.load(repositoryID: "other/repo", original: item.original, target: "ko")
        precondition(changed == nil && english == nil && another == nil)
        let newItem = DescriptionTranslation(repositoryID: item.repositoryID, original: "새 원문", target: "en", source: "ko", text: "New original")
        try storage.save(newItem)
        let previous = try storage.load(repositoryID: item.repositoryID, original: item.original, target: "ko")
        precondition(previous == item)
        let key = DescriptionTranslation.key(repositoryID: item.repositoryID, original: item.original, target: "ko")
        let file = directory.appendingPathComponent(key + ".json")
        try JSONEncoder().encode(newItem).write(to: file)
        let mismatched = try storage.load(repositoryID: item.repositoryID, original: item.original, target: "ko")
        precondition(mismatched == nil)
        try Data("broken".utf8).write(to: file)
        var rejected = false
        do { _ = try storage.load(repositoryID: item.repositoryID, original: item.original, target: "ko") } catch { rejected = true }
        precondition(rejected)
        var invalidRejected = false
        do { try storage.save(DescriptionTranslation(repositoryID: "x/y", original: "Original", target: "ko", source: "en", text: "  ")) } catch { invalidRejected = true }
        precondition(invalidRejected)
        precondition(DescriptionTranslation.key(repositoryID: "a", original: "bc", target: "ko") != DescriptionTranslation.key(repositoryID: "ab", original: "c", target: "ko"))
        print("PASS: translation persistence, original/target/repository isolation, cache identity validation, corrupt/empty rejection, collision-safe keys")
    }
}
