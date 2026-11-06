import SwiftUI
import AppKit
#if GITMORNING_WITH_SPARKLE
import Sparkle
#endif

/// Sparkle owns version comparison, skipped versions, signature validation,
/// download, installation, and relaunch. Never replace the app with a custom script.
@MainActor final class AppUpdater: ObservableObject {
    @Published private(set) var canCheck = true
    @Published private(set) var configured = false
    @Published var automaticallyChecks = false {
        didSet {
            #if GITMORNING_WITH_SPARKLE
            if let updater = controller?.updater, updater.automaticallyChecksForUpdates != automaticallyChecks {
                updater.automaticallyChecksForUpdates = automaticallyChecks
            }
            #endif
        }
    }
    #if GITMORNING_WITH_SPARKLE
    private var controller: SPUStandardUpdaterController?
    private var observation: NSKeyValueObservation?
    #endif

    init() {
        #if GITMORNING_WITH_SPARKLE
        guard let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https", url.host != nil,
              let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        configured = true
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
            let enabled = change.newValue ?? false
            Task { @MainActor in self?.canCheck = enabled }
        }
        #endif
    }

    func checkForUpdates() {
        #if GITMORNING_WITH_SPARKLE
        if let controller { controller.checkForUpdates(nil); return }
        #endif
        let alert = NSAlert()
        alert.messageText = "Updates not configured"
        alert.informativeText = "This development build has no update feed or signing key configured. Distribution builds support update notifications and installation with relaunch."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
