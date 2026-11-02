<p align="center"><img src="https://github.com/ddingddong9/homebrew-gitmorning/releases/download/v0.3.0/icon.png" alt="GitMorning" width="112" /></p>
<h1 align="center">GitMorning</h1>
<p align="center"><strong>Discover what’s next.</strong><br />Explore GitHub Trending in a native Mac app. No AI required.</p>
<p align="center"><strong>English</strong> · <a href="README.ko.md">한국어</a></p>
<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?logo=apple" />
  <img alt="Native SwiftUI" src="https://img.shields.io/badge/SwiftUI-Native-orange?logo=swift" />
  <img alt="Preview" src="https://img.shields.io/badge/status-preview-lightgrey" />
</p>
<p align="center"><a href="#install">Install</a> · <a href="#features">Features</a> · <a href="#optional-korean-explanations">한국어</a> · <a href="#updates">Updates</a> · <a href="#faq">FAQ</a></p>

---

## Meet GitMorning

Find interesting open-source projects, read what they do, and save the ones you want to try. GitMorning brings GitHub Trending into a focused, three-column macOS interface.

**Original descriptions are the default.** Browsing, search, stars, and saved projects work without an AI model, an API key, an account, or a subscription. Descriptions are shown in the language provided by each repository; they are not automatically translated into English.

## Install

On an Apple Silicon Mac with Homebrew:

```sh
brew install --cask ddingddong9/gitmorning/gitmorning
```

Or download the ZIP from [Releases](https://github.com/ddingddong9/homebrew-gitmorning/releases/latest) and move **GitMorning.app** to Applications.

| Feature | Requirements |
| --- | --- |
| Browse, search, save, and read original descriptions | macOS 14+, Apple Silicon |
| Optional Korean AI explanations | macOS 26+, Apple Intelligence enabled, a ready model supporting Korean |
| New data, README downloads, and app updates | Internet connection |
| Bundled snapshots and previously saved content | Available offline |

This is an **ad-hoc signed, non-notarized preview**. macOS may require approval before the first launch. No security-bypass commands are included in the installer. Intel builds are not available yet.

## Features

- **Daily and weekly discovery:** original Trending order, total stars, and period growth.
- **Descriptions without AI:** read the original repository description immediately.
- **Save for later:** keep projects and their captured metrics after they leave Trending.
- **Find what matters:** search by project or description and choose available language feeds.
- **Optional Korean explanations:** explicitly request an on-device explanation of a README.
- **Comfortable reading:** light/dark themes, larger text, and a centered native window.
- **In-app updates:** review release notes, install and relaunch, skip a version, or be reminded later.

Snapshots show their collection time. Bundled data is not a live feed. An optional HTTPS data address can supply newer snapshots; an unavailable period or language is never replaced by a misleading filtered list.

## Start exploring

1. Select **Today’s Trending** or **Weekly Trending**.
2. Choose a project and read its **Original description**. No generation or translation runs.
3. Use **Save** to keep it or **Open on GitHub** for the full documentation.

| Shortcut | Action |
| --- | --- |
| `⌘F` | Search this list |
| `⌘D` | Save / unsave |
| `⇧⌘O` | Open on GitHub |
| `⌘R` | Refresh the list |
| `⌘,` | Settings |

## Optional Korean explanations

Expand **Korean explanation · optional AI** and choose **Explain in Korean** only when you want help reading a README. This is a generated explanation of a document excerpt, not a word-for-word translation.

The Apple on-device model performs generation on your Mac. There is no paid LLM API or automatic cloud fallback. Unsupported Macs can still browse original descriptions normally.

Explanations are cached locally. **Check README for changes** reuses a cached explanation when the document is unchanged. The list continues to show original descriptions unless you explicitly enable **Show saved Korean explanations in the list** in Settings.

AI can omit or misstate details. The source README and generation time are shown alongside the result. Verify installation requirements, pricing, and licenses in the original project.

## Updates

[ Sparkle ](https://sparkle-project.org/) checks the signed update archive before installation. Automatic checking is enabled in distribution builds; automatic installation is off.

- **Install Update / Install & Relaunch:** download, validate, install, and reopen the app.
- **Skip This Version:** suppress automatic reminders for that version.
- **Remind Me Later:** keep your current version and check again later.

Button wording follows the update stage and system language. Use **GitMorning → Check for Updates…** to check manually. You can disable automatic checking in Settings.

You can also update explicitly with Homebrew:

```sh
brew update
brew upgrade --cask gitmorning
```

## Privacy and cost

Saved projects and generated explanations stay on your Mac. No account sync, advertising, or app analytics is configured. The app contacts GitHub for requested data and READMEs, and the public update feed for app updates.

Browsing descriptions does not use AI. Optional on-device generation has no LLM API usage charge. A Developer ID signed/notarized distribution would require separate Apple developer setup; the preview is not Apple-notarized.

## FAQ

**Do I need Apple Intelligence?**

Only for the optional Korean explanation feature. Ordinary browsing and saving do not need it.

**Are descriptions always English?**

The interface is English. Repository descriptions remain exactly in their source language. Translating every non-English description is not part of the default mode.

**Can I use it offline?**

You can read bundled/cached snapshots and saved content. New data, READMEs, and updates need a connection.

**Is this MIT licensed or Apple certified?**

Neither is claimed for the application at this stage. The source remains private and its license is not yet selected. Sparkle’s MIT license and third-party notices are preserved. Apple notarization is separate from source licensing and from Sparkle’s update signatures.

## Feedback

Report bugs or suggest features in [Issues](https://github.com/ddingddong9/homebrew-gitmorning/issues). The public distribution repository contains the cask, releases, update feed, and user documentation. Application source is maintained separately.

