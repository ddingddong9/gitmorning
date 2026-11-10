## Summary

<!-- What problem does this solve, and what changes for the user? Link the issue; use "Closes #123" only when this PR fully resolves it. Korean or English is fine. -->

## Verification

<!-- List what you ran and the result. For behavior changes, give steps someone else can repeat. Say what you could not check instead of leaving it out. -->

- Checks and results:
- Steps to verify:
- Not verified:

## Screenshots (required for UI changes)

<!-- UI changes must include screenshots of the changed screens, before and after when you change an existing one. Light and dark, or English and Korean, when the change affects them. Remove this section if the PR does not change UI. -->

## Risks

<!-- What could break? For example saved data or caches from older versions, the shared feed format, the Trending parser, translations, updates. Otherwise write "None". -->

## Checklist

- [ ] I read [AGENTS.md](https://github.com/ddingddong9/gitmorning/blob/main/AGENTS.md) (project rules and what reviews look for).
- [ ] I listed verification results and anything left unverified.
- [ ] UI changes: screenshots attached, and every new interface string has a Korean entry in `Sources/GitMorning/Resources/Korean.json` (otherwise N/A).
- [ ] Trending parser changes: Python (`pipeline/collect.py`) and Swift (`TrendingReader.swift`) changed together, with the shared fixtures (otherwise N/A).
- [ ] No binaries, caches, tokens, signing keys, or personal data in code, logs, or screenshots.

### Release changes only

<!-- Remove this section unless the PR changes how releases are built or published. A PR never publishes a release; a v* tag on main does. -->

- [ ] I did not hand-edit `Casks/gitmorning.rb`, `distribution/appcast.xml`, or version/SHA values; release workflows own them.
- [ ] The bundle identifier and the Sparkle public key are unchanged.
