# Licensing and Apple distribution

These are separate decisions. Neither an MIT badge nor Sparkle's update signature means an application has been notarized by Apple.

## MIT license

MIT is a software license, not a paid certification. It allows recipients to use, modify, redistribute, and sell the covered software, subject to retaining its copyright and permission notice. It includes a warranty disclaimer.

To adopt it for code you own, choose the copyright holder and year, add the actual license text in a root LICENSE file, and keep third-party notices. Do not label the entire app MIT merely because one dependency uses MIT. Changing repository visibility is also a separate decision; applying a permissive license grants rights and should be an explicit owner choice.

**Current status:** GitMorning's source is public under the MIT license (root `LICENSE`, 2026-11-06). Third-party notices stay with their code: Sparkle's license ships in the app's framework, and each skill under `.claude/skills/` keeps its own `LICENSE`.

## Developer ID signing and notarization

Apple Developer ID identifies the publisher of a Mac application distributed outside the Mac App Store. Apple's notary service checks submitted software and issues a notarization ticket after acceptance. This is separate from App Store review and from a source license.

The normal route is:

1. The owner enrolls in the Apple Developer Program, normally USD 99 per membership year in local currency where available.
2. The owner creates or provides a Developer ID Application certificate through the Apple account/Xcode and installs it in the signing Keychain.
3. Build and sign the app and nested Sparkle helpers using the same Developer ID, with Hardened Runtime and secure timestamps.
4. Submit a distribution archive using Apple's notarytool, inspect the result, and staple the accepted ticket to the app.
5. Package and sign the final archive for Sparkle, generate its checksum/cask, then verify Gatekeeper behavior on a clean Mac.

A Developer ID signing identity, Apple notarization tools, and authenticated notary access are needed for that route. A free developer account alone does not provide this distribution setup. The owner must perform account/payment/agreements and any credential setup; none has been done automatically.

**Current status:** the preview is ad-hoc signed and not notarized. First launch may require macOS approval. Homebrew installation does not remove this requirement. No quarantine removal or other security bypass is included. No Apple certification claim is made.

## Sparkle update signing

Sparkle uses a separate Ed25519 key to authenticate update archives. This is free and does not replace Developer ID or Apple notarization. The signing private key stays in a local, ignored directory with restrictive permissions; only the public key/signature are distributed.

The 0.3.0 → 0.4.0 update has been exercised through the native update window, including Skip This Version, manual recheck, download, Install and Relaunch, and verification of the installed bundle version. This confirms the tested update path, not Apple notarization or a clean-Mac Homebrew install.

## Official references

- https://opensource.org/license/mit
- https://choosealicense.com/licenses/mit/
- https://developer.apple.com/programs/
- https://developer.apple.com/help/account/certificates/create-developer-id-certificates/
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- https://sparkle-project.org/documentation/
