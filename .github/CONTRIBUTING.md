# Contributing to GitMorning

Thanks for helping! Bug reports, ideas, and pull requests are all welcome. Korean or English is fine. (한국어로 작성해도 됩니다.)

## Reporting a bug or idea

Open an [issue](https://github.com/ddingddong9/gitmorning/issues/new/choose). For bugs, include your GitMorning version (Settings → Updates), macOS version, and what you expected to see.

## Working on code

GitMorning is a SwiftPM app with no Xcode project.

```sh
GITMORNING_CORE_ONLY=1 swift build              # app without the updater
python3 -m unittest discover -s pipeline/tests  # collector, README excerpts, canary
zsh scripts/build-app.sh                         # GitMorning.app in dist/
swift test --disable-sandbox                     # needs Xcode (XCTest)
```

With only the Command Line Tools, run the standalone checks instead, for example:

```sh
swiftc Sources/GitMorningCore/*.swift scripts/check-core.swift -o .build/check-core && .build/check-core
```

[docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) lists every check and how to capture UI snapshots; [docs/discovery.md](../docs/discovery.md) explains how features behave.

## Pull requests

- Branch from `main` (`feat/…`, `fix/…`, `docs/…`) and keep each PR to one change.
- Use `feat:`, `fix:`, `docs:`, `test:`, `chore:` commit prefixes.
- Describe what changes for the user and how you checked it. CI must pass before merging.
- When you change the Trending parser, update both `pipeline/collect.py` and `Sources/GitMorningCore/TrendingReader.swift`, and the shared fixtures in `pipeline/tests/fixtures/parity/`.
- Never commit app binaries, caches, API keys, or release signing keys (`.release-secrets/` is ignored).

Found a security problem? Please report it privately as described in [SECURITY.md](SECURITY.md).

By contributing, you agree that your contribution is licensed under the [MIT License](../LICENSE).

---

## 한국어 요약

- 버그·아이디어는 이슈로, 코드 변경은 `main`에서 브랜치를 만들어 PR로 보내 주세요.
- 트렌딩 파서를 바꾸면 Python(`pipeline/collect.py`)과 Swift(`TrendingReader.swift`), 공유 픽스처를 함께 고쳐 주세요.
- 바이너리·캐시·API 키·서명 키는 커밋하지 않습니다.
- 기여한 코드는 MIT 라이선스로 배포됩니다.
