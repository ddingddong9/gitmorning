import Foundation

// Standalone checks for README translation links (no network).
@main
struct ReadmeVariantChecks {
    static func main() {
        let html = """
        <p align="center"><a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="./docs/README_JP.md">日本語</a>
        · <a href="readme_i18n/README_zh_TW.md">繁體中文</a> · <a href="https://github.com/Owner/Tool/blob/main/docs/pt-BR/README.md#top">Português</a>
        · <a href="docs/i18n/README-%E7%AE%80%E4%BD%93.md">🇨🇳 简体中文</a> · <a href="README.ko-KR.md">한국어 (again)</a></p>
        <p><a href="README_OLD.md">old notes</a> <a href="https://github.com/other/repo/blob/main/README.es.md">elsewhere</a>
        <a href="https://example.com/README.fr.md">external</a> <a href="CONTRIBUTING.md">Contributing</a> <a href="#install">Install</a>
        <a href="../outside/README.de.md">outside</a> <a href="docs/README_V2.md">v2</a> <a href="docs/guide.md">Deutsch</a></p>
        """
        let found = ReadmeVariant.find(in: html, repository: "owner/tool")
        precondition(found.map(\.language) == ["ko", "ja", "zh-TW", "pt-BR", "zh-CN"], "\(found)")
        precondition(found.map(\.path) == ["README.ko.md", "docs/README_JP.md", "readme_i18n/README_zh_TW.md", "docs/pt-BR/README.md", "docs/i18n/README-简体.md"], "\(found)")
        precondition(found[1].directory == "docs/" && found[0].directory == "")
        precondition(ReadmeVariant.find(in: html, repository: "owner/tool", current: "README.ko.md").map(\.path) == ["README.md", "docs/README_JP.md", "readme_i18n/README_zh_TW.md", "docs/pt-BR/README.md", "docs/i18n/README-简体.md", "README.ko-KR.md"])
        precondition(ReadmeVariant.language(code: "zh_CN") == "zh-CN" && ReadmeVariant.language(code: "EN") == "en"
                     && ReadmeVariant.language(code: "kr") == "ko" && ReadmeVariant.language(code: "pt_BR") == "pt-BR"
                     && ReadmeVariant.language(code: "old") == nil && ReadmeVariant.language(code: "v2") == nil)
        precondition(ReadmeVariant.find(in: "<p>No links</p>", repository: "owner/tool").isEmpty)
        precondition(ReadmeReader.url("owner/tool", path: nil)?.absoluteString == "https://api.github.com/repos/owner/tool/readme")
        precondition(ReadmeReader.url("owner/tool", path: "docs/README 한국어.md")?.absoluteString == "https://api.github.com/repos/owner/tool/contents/docs/README%20%ED%95%9C%EA%B5%AD%EC%96%B4.md")
        precondition(ReadmeReader.url("owner/tool", path: "docs/../secret") == nil && ReadmeReader.url("owner/tool", path: "a?b#c")?.absoluteString.hasSuffix("a%3Fb%23c") == true)
        precondition(ReadmeReader.hasExpiringImages("<img src=\"https://private-user-images.githubusercontent.com/1/a.png?jwt=x\">")
                     && !ReadmeReader.hasExpiringImages("<img src=\"https://camo.githubusercontent.com/a\">"))
        print("PASS: README translations — file, folder and link-text languages, github.com links, one per language, outside links and non-languages ignored, safe file addresses, expiring image links not cached")
    }
}
