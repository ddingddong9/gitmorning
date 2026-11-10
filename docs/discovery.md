# Local discovery and interface languages

Status: development build, not yet published to Homebrew. Builds on the native Settings window.

- Settings → Language & AI → Interface language: English or 한국어. Until the user chooses, it follows macOS: 한국어 when the first preferred language is Korean, otherwise English (`InterfaceLanguage.registerSystemDefault`). App-provided labels, actions, settings, and Project commands change immediately and survive relaunch. Native system menus and Sparkle have their own system localization behavior.
- Description translation is on by default: descriptions automatically follow the English / 한국어 interface language using Apple Translation on macOS 15+. Supported language data may need a system download prompt. No paid API, server, or Apple Intelligence is required. Users can disable automatic translation in Settings. README previews remain original. Korean AI explanations are a separate explicit action.
- With no custom feed address, the app fetches the exact daily/weekly and language-specific GitHub Trending page at launch, feed changes, and manual refresh. It validates the full response before caching. Failure keeps the last valid cache or bundled snapshot and reports its age. No server, account, paid API, or scheduled background collector is required. There is no refresh while the app is closed.
- Since last visit shows projects newly present or ranked higher compared with the previous visit to the same period and language. The comparison baseline stays fixed during a launch; the latest valid list is saved for the next launch. First visits have no change claims. Source ranks remain unchanged by filters. Removed projects are not shown in the current list.
- Read/unread is explicit; automatic selection does not mark a project read. Hidden projects disappear from normal lists and can be restored through the Hidden filter. These flags apply to a repository across feeds.
- Saved projects have a note and Try later / Testing / In use status. Save note commits the current draft. Drafts are not auto-saved when leaving a project. Notes remain local even if a bookmark is removed, so saving the project again restores them.
- README preview fetches the original document on request without AI. It shows plain Markdown/HTML source, up to 40,000 characters, without executing HTML or fetching embedded images. The full document remains available on GitHub.

Discovery metadata lives in `Application Support/GitMorning/discovery-v1.json`, separately from existing bookmarks and explanations. Writes are atomic; an unreadable store disables writes rather than overwriting notes. Only validated snapshots update visit history. There is no account sync.

## Automatic description translation

Descriptions are grouped by detected source language; a session never mixes sources. Groups run serially and successful items are cached independently. Failed or unsupported items retain their original text and a retry action; no cloud fallback runs. A changed app language or input cancels the previous worker and rejects late results. Already matching source/target languages and missing descriptions do not invoke translation.

Cache identity includes repository ID, exact original description, target language, and translation engine version. Switching language cannot display stale translations from another target. Original strings remain unchanged in snapshots and saved projects. A translated detail includes Show original. Search includes current-language translated descriptions.

Generated explanation text no longer overrides list descriptions, even if the older showKoreanInList preference remains on disk. A cached translation is distinct from an AI explanation.

## Validation

```sh
swiftc Sources/GitMorningCore/*.swift scripts/check-discovery.swift -o .build/check-discovery
.build/check-discovery
```

This exercises HTML structure, text order and entities, missing metrics, hidden/template content, invalid/duplicate rejection, rank deltas, isolated period/language keys, durable notes and flags, and corrupt-file preservation.

Native QA: direct live refresh; English → 한국어; localized main/settings/Project menu; language/read/note/status persistence after relaunch; hide/filter/unhide; README fetch. Temporary QA notes and flags were restored afterwards. Automatic description translation is covered by the separate translation cache checks below.

```sh
swiftc Sources/GitMorningCore/*.swift scripts/check-translations.swift -o .build/check-translations
.build/check-translations
```

Translation checks cover persistence; original/target/repository isolation; mismatched or corrupt cache rejection; empty-result rejection; and unambiguous cache keys.

Native translation QA (development 0.7.0): downloaded the system English/Korean and Chinese language data; translated all 16 non-empty descriptions in the 17-project daily list to Korean; checked list/detail consistency and Show original; relaunched and reused all 16 cached Korean translations; searched the translated word 헤드리스; toggled translation off/on; switched to English and verified the Chinese original translated into English while already-English descriptions remained original. Failure fallback and Retry were observed before language downloads completed. No generated Korean AI explanation was invoked.

## Morning brief

Status: development build. Settings → Morning brief.

- Once per local day, at or after the brief time (default 08:00), GitMorning fetches the daily all-languages Trending list and compares it with the previous day's brief. It lists up to 10 projects that are new to the list or ranked higher, in source rank order, and counts all of them. Hidden projects are excluded. The first brief has nothing to compare with, so it shows the top projects without change claims.
- Same-day refreshes ("Update brief") keep yesterday's brief as the comparison base, so the result never becomes "since ten minutes ago".
- The menu bar item (on by default) shows the brief and opens a project in the main window. It also keeps GitMorning running after the main window closes; with the menu bar item off, the brief updates only while the window is open.
- The notification is off by default. Turning it on asks for macOS notification permission; if denied, the setting turns itself back off. A notification is posted only by the scheduled daily brief, at most once per day, and only when there is something new or it is the first brief. Clicking it opens the main window.
- No server, account, background agent, or launch-at-login item. If GitMorning is not running at the brief time, the brief is built the next time it runs after that time.
- Uses the custom HTTPS feed address when set, otherwise GitHub Trending directly. A successful download also refreshes the main list's cache. Failure keeps the last brief and says so.

Stored in `Application Support/GitMorning/brief-v1.json` (derived data; an unreadable file is replaced by the next brief).

```sh
swiftc Sources/GitMorningCore/*.swift scripts/check-brief.swift -o .build/check-brief
.build/check-brief
```

## README requests and GitHub's anonymous limit

README preview and on-device explanations use GitHub's public API without an account, which allows 60 requests per hour per IP address. Everyone behind one office or school network shares that budget.

- README text is kept in `Application Support/GitMorning/readmes/` with its ETag.
- Preview reuses a copy fetched within 6 hours without any request. Older copies are revalidated with `If-None-Match`; an unchanged README returns 304 and is not downloaded again. Unauthenticated 304 responses still count toward the hourly limit, so the 6-hour reuse is what saves requests.
- "Explain in Korean" / "Check README for changes" always revalidates, so explanations are never built from an outdated README unless GitHub refuses the request.
- When the limit is reached (403 with `x-ratelimit-remaining: 0`, or 429), a cached copy is shown if one exists; otherwise the app says the network's hourly limit was reached instead of blaming the connection. Browsing lists is unaffected.

## Open at login

Settings → Morning brief and the menu bar's ⋯ menu offer "Open GitMorning at login" through macOS login items (`SMAppService`). It is off by default; macOS tells the user when it is added and may ask for approval in System Settings → General → Login Items.

## Shared feed (default data source)

With no custom address, lists come from a shared feed instead of every app parsing GitHub's page:

- This repository runs `.github/workflows/publish-trending.yml` on an hourly schedule (minute 41, away from the busy top of the hour). It collects all 14 period/language pages with `feed/build_site.py`, which imports `pipeline/collect.py` and publishes them to GitHub Pages at `https://ddingddong9.github.io/gitmorning/v1/` with a `manifest.json`. A page that fails keeps its previously published file. Daily lists also publish `history-daily-<language>.json` (`pipeline/history.py`): each repository's rank for the last 14 UTC days, listed under `history` in the manifest. Public-repository Actions and Pages cost nothing.
- The app (`TrendingSource`) reads that feed first and uses it when it is at most 8 hours old (the workflow is scheduled hourly, but GitHub runs it only every few hours). Otherwise it reads GitHub Trending directly; if GitHub is also unreachable, an older shared list is shown rather than an error. A shared list older than one the app already has never replaces it.
- A custom HTTPS address (`defaults write dev.gitmorning.prototype feedBaseURL https://…`; not in Settings) is used alone, with no fallback.
- Watch points: the canary (four times a day, since GitHub can skip scheduled runs) opens a `trending-canary` issue when the feed is older than 8 hours or incomplete. GitHub disables scheduled workflows in a public repository after 60 days without commits; the canary catches that, and re-enabling the workflow fixes it.

```sh
swiftc Sources/GitMorningCore/*.swift scripts/check-source.swift -o .build/check-source && .build/check-source
swiftc Sources/GitMorningCore/*.swift scripts/check-feed.swift -o .build/check-feed && .build/check-feed https://ddingddong9.github.io/gitmorning/v1 3
```
