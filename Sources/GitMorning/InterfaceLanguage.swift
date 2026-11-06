import SwiftUI

enum InterfaceLanguage: String, CaseIterable, Identifiable {
    case english = "en", korean = "ko"
    var id: String { rawValue }
    var title: String { self == .english ? "English" : "한국어" }
    var locale: Locale { Locale(identifier: rawValue) }
    /// First-launch default: Korean when macOS prefers Korean, otherwise English.
    /// Only used until the user picks a language in Settings.
    static func matching(_ preferred: [String] = Locale.preferredLanguages) -> InterfaceLanguage {
        preferred.first.map { $0.lowercased().hasPrefix("ko") } == true ? .korean : .english
    }
    /// Makes every @AppStorage("interfaceLanguage") read the macOS-based default until a choice is saved.
    static func registerSystemDefault() {
        UserDefaults.standard.register(defaults: ["interfaceLanguage": matching().rawValue])
    }
    func text(_ source: String) -> String { self == .korean ? Self.koreanStrings[source] ?? source : source }
    private static let koreanStrings: [String: String] = {
        let url = Bundle.main.bundleURL.pathExtension == "app"
            ? Bundle.main.resourceURL?.appendingPathComponent("Korean.json")
            : Bundle.module.url(forResource: "Korean", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url), let strings = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return strings
    }()
}
