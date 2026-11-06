import Foundation
import GitMorningCore

extension ReadmeCache {
    /// README copies shared by the preview and on-device explanations.
    static let app = ReadmeCache(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GitMorning").appendingPathComponent("readmes"))
    /// GitHub-rendered README HTML for the preview, cached apart from the Markdown source.
    static let appHTML = ReadmeCache(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("GitMorning").appendingPathComponent("readmes-html"))
}

import ServiceManagement

/// "Open at login" through macOS's own login items. Off until the user turns it on,
/// and macOS shows the user that it was added.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    /// Returns a message to show, or nil when the change succeeded.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            return enabled ? "Could not add GitMorning to login items. Move it to Applications and try again." : nil
        }
        return needsApproval ? "Allow GitMorning in System Settings → General → Login Items." : nil
    }
}
