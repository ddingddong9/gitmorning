<p align="center"><img src="https://github.com/ddingddong9/gitmorning/releases/download/v0.3.0/icon.png" alt="GitMorning" width="112" /></p>
<h1 align="center">GitMorning</h1>
<p align="center"><strong>Discover what’s next.</strong><br />A native Mac app for reading GitHub Trending</p>
<p align="center"><strong>English</strong> · <a href="README.ko.md">한국어</a></p>

---

See which open-source projects are trending, read what they do, and save the ones you want to try later. No account, API key, or subscription.

## Install

```sh
brew tap ddingddong9/gitmorning https://github.com/ddingddong9/gitmorning
brew install --cask gitmorning
```

Or download the ZIP from the [latest release](https://github.com/ddingddong9/gitmorning/releases/latest) and move **GitMorning.app** to Applications.

- macOS 14 or later, Apple Silicon
- This preview is not notarized yet, so macOS may block the first launch. Choose **System Settings → Privacy & Security → Open Anyway**.

## Features

- **Daily and weekly Trending:** original rank, total stars, and growth for the period
- **Saved projects:** keep what a project looked like even after it leaves Trending
- **Search and language lists:** Python, TypeScript, JavaScript, Swift, Go, Rust
- **Korean explanations (optional):** an on-device summary of the README, only when you ask. Needs macOS 26 and Apple Intelligence
- **Light and dark mode, larger text**
- **In-app updates:** you are told about a new version and choose when to install

| Shortcut | Action |
| --- | --- |
| `⌘F` | Search the list |
| `⌘D` | Save / unsave |
| `⇧⌘O` | Open on GitHub |
| `⌘R` | Refresh |
| `⌘,` | Settings |

## Updates

The app checks for updates on its own. If you installed with Homebrew, you can also run:

```sh
brew upgrade --cask gitmorning
```

## Privacy

Saved projects, notes, and explanations stay on your Mac. No ads or usage tracking.

## This repository

Release downloads, the Homebrew cask, and the shared Trending data the app reads (`feed/`, refreshed hourly). The app source is kept separately.

Report bugs or suggest features in [Issues](https://github.com/ddingddong9/gitmorning/issues).
