import SwiftUI
import WebKit
import GitMorningCore

/// Shows GitHub's rendered README HTML. GitHub already sanitizes it (no scripts,
/// external images through its image proxy); the view also turns JavaScript off,
/// keeps no website data, allows only images and inline styles, and opens every
/// link in the default browser instead of navigating inside the app.
struct ReadmeWebView: NSViewRepresentable {
    let html: String
    let repository: Repository
    let fontSize: CGFloat
    /// Folder of the shown file inside the repository ("" for the main README), with a trailing slash.
    var directory = ""

    /// Relative image paths in a README point into the repository; raw.githubusercontent.com serves them.
    private var baseURL: URL? {
        URL(string: "https://raw.githubusercontent.com/\(repository.fullName)/HEAD/" + (directory.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""))
    }

    func makeCoordinator() -> Coordinator { Coordinator(repository: repository) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let page = Self.page(html, fontSize: fontSize)
        guard context.coordinator.loaded != page + directory else { return }
        context.coordinator.loaded = page + directory
        context.coordinator.repository = repository
        view.loadHTMLString(page, baseURL: baseURL)
    }

    static func page(_ body: String, fontSize: CGFloat) -> String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src https: data:; style-src 'unsafe-inline'; media-src https:">
        <meta name="color-scheme" content="light dark">
        <style>\(css(fontSize))</style></head><body>\(body)</body></html>
        """
    }

    private static func css(_ size: CGFloat) -> String {
        """
        :root { --fg:#1f2328; --muted:#59636e; --border:#d1d9e0; --code:#f6f8fa; --link:#0969da; }
        @media (prefers-color-scheme: dark) { :root { --fg:#e6edf3; --muted:#9198a1; --border:#3d444d; --code:#262c36; --link:#4493f8; } }
        html { background: transparent; }
        body { margin: 0; padding: 4px 20px 24px 4px; color: var(--fg); background: transparent;
               font: \(Int(size))px/1.6 -apple-system, BlinkMacSystemFont, "Apple SD Gothic Neo", sans-serif; word-wrap: break-word; }
        a { color: var(--link); text-decoration: none; } a:hover { text-decoration: underline; }
        h1, h2, h3, h4, h5, h6 { margin: 1.4em 0 0.6em; line-height: 1.25; font-weight: 600; }
        h1 { font-size: 1.8em; } h2 { font-size: 1.4em; } h3 { font-size: 1.2em; } h4 { font-size: 1em; }
        h1, h2 { padding-bottom: 0.3em; border-bottom: 1px solid var(--border); }
        .markdown-heading { position: relative; } .anchor, .octicon { display: none; }
        p, ul, ol, blockquote, pre, table, details { margin: 0 0 1em; }
        ul, ol { padding-left: 2em; } li + li { margin-top: 0.25em; }
        img { max-width: 100%; height: auto; } p[align="center"], div[align="center"] { text-align: center; }
        code, pre { font: 0.86em/1.45 ui-monospace, "SF Mono", Menlo, monospace; }
        code { padding: 0.2em 0.4em; border-radius: 6px; background: var(--code); }
        pre { padding: 14px 16px; overflow: auto; border-radius: 8px; background: var(--code); }
        pre code { padding: 0; background: none; font-size: 1em; }
        blockquote { padding: 0 1em; color: var(--muted); border-left: 0.25em solid var(--border); }
        .markdown-alert { padding: 0.5em 1em; border-left: 0.25em solid var(--link); }
        .markdown-alert-title { font-weight: 600; }
        table { border-collapse: collapse; display: block; max-width: 100%; overflow: auto; }
        th, td { padding: 6px 13px; border: 1px solid var(--border); } th { font-weight: 600; }
        hr { height: 1px; border: 0; background: var(--border); margin: 1.5em 0; }
        summary { cursor: pointer; }
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var repository: Repository
        var loaded: String?
        init(repository: Repository) { self.repository = repository }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard action.navigationType == .linkActivated, let url = action.request.url else {
                // The initial page load; anything else (forms, redirects, frames) is refused.
                decisionHandler(action.navigationType == .other && action.targetFrame?.isMainFrame == true ? .allow : .cancel); return
            }
            // In-page anchors (table of contents) scroll inside the preview.
            if url.fragment != nil, let current = webView.url,
               url.absoluteString.components(separatedBy: "#").first == current.absoluteString.components(separatedBy: "#").first {
                decisionHandler(.allow); return
            }
            decisionHandler(.cancel)
            if let target = Self.browserURL(url, repository: repository.fullName) { NSWorkspace.shared.open(target) }
        }

        /// Links relative to the README resolve against raw.githubusercontent.com; send people to the GitHub page instead.
        static func browserURL(_ url: URL, repository: String) -> URL? {
            guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
            let rawPrefix = "https://raw.githubusercontent.com/\(repository)/HEAD/"
            if url.absoluteString.hasPrefix(rawPrefix) {
                return URL(string: "https://github.com/\(repository)/blob/HEAD/" + url.absoluteString.dropFirst(rawPrefix.count))
            }
            return url
        }
    }
}
