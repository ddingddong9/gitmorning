# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems. Report them privately through
[GitHub's private vulnerability reporting](https://github.com/ddingddong9/gitmorning/security/advisories/new)
(Security → Report a vulnerability). Include the GitMorning version, macOS version, and steps to reproduce.

You should get a reply within a week. Fixes ship as a new release through the in-app updater and Homebrew.
Korean or English is fine. (한국어로 신고해도 됩니다.)

## Supported versions

Only the latest release receives fixes. The in-app updater (Sparkle, Ed25519-signed) and
`brew upgrade --cask gitmorning` install it.

## What GitMorning does and does not do

- No account, analytics, or server of its own. Saved projects, notes, and caches stay in
  `~/Library/Application Support/GitMorning`.
- Network access: the shared feed on GitHub Pages, github.com Trending and release pages, and
  the GitHub REST API for READMEs — all over HTTPS. Updates are verified with Ed25519 before they
  are installed.
- README previews show GitHub-rendered HTML with JavaScript disabled, no stored website data, a
  restrictive Content Security Policy, and links opened in your browser.
- The app is ad-hoc signed and not yet notarized by Apple.
