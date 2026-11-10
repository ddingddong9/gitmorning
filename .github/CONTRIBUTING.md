# Contributing to GitMorning

Thanks for helping! Bug reports, ideas, and pull requests are all welcome. Korean or English is fine. (한국어로 작성해도 됩니다.)

## Reporting a bug or idea

Open an [issue](https://github.com/ddingddong9/gitmorning/issues/new/choose) and pick **Bug report** or **Feature idea**. The bug form asks for your GitMorning version (bottom of Settings), macOS version, how you installed it, and steps to reproduce. Remove personal details from screenshots. Security problems go through [private reporting](SECURITY.md), not issues.

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

Read [AGENTS.md](../AGENTS.md) first: it holds the project rules and the list of things reviews check.

- Branch from `main` (`feat/…`, `fix/…`, `docs/…`) and keep each PR to one change. For a larger change, open an issue first so we can agree on the approach.
- Use lowercase Conventional Commits: `feat(scope): …`, `fix: …`, `docs: …`, `test: …`, `chore: …`.
- Fill in the PR template: the problem, what you ran and the result, what you could not check, and risks. **UI changes need screenshots** (before and after).
- Every new interface string needs a Korean entry in `Sources/GitMorning/Resources/Korean.json` (`python3 scripts/check-ui-strings.py` checks it). Machine translation is fine; the maintainer will adjust it.
- When you change the Trending parser, update both `pipeline/collect.py` and `Sources/GitMorningCore/TrendingReader.swift`, and the shared fixtures in `pipeline/tests/fixtures/parity/`.
- Never commit app binaries, caches, API keys, or release signing keys (`.release-secrets/` is ignored). Do not edit release versions, SHA-256 values, the cask, or the appcast by hand.

## Checks and review

Every pull request runs CI ([ci.yml](workflows/ci.yml)): the Python collector and release-script tests, the Korean string check, workflow validation (actionlint), and, when app code changes, the Swift checks, parser parity against the live Trending page, `swift test`, and an app build. Pull requests from forks run without repository secrets. A first-time contributor's run starts after the maintainer approves it.

`main` is protected: changes land only through a pull request with CI passing on its latest commit. The maintainer reviews every pull request; [CodeRabbit](https://www.coderabbit.ai) also reviews each pull request automatically (in Korean, configured in [`.coderabbit.yaml`](../.coderabbit.yaml)); it follows the **Code Review Rules** in AGENTS.md and is advice, not approval. Reply to it in the PR, or comment `@coderabbitai review` to ask for another pass. Releases are made by the maintainer from a `v*` tag; merging a PR does not publish anything.

Found a security problem? Please report it privately as described in [SECURITY.md](SECURITY.md). Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md).

By contributing, you agree that your contribution is licensed under the [MIT License](../LICENSE).

---

## 한국어 요약

- 버그·아이디어는 이슈 양식으로, 코드 변경은 `main`에서 브랜치를 만들어 PR로 보내 주세요. 먼저 [AGENTS.md](../AGENTS.md)의 규칙을 읽어 주세요.
- PR 템플릿에 문제·검증 결과·확인하지 못한 점·위험을 적고, 화면이 바뀌면 스크린샷을 붙여 주세요.
- 새 화면 문구는 `Korean.json`에 한국어를 함께 넣어 주세요(`python3 scripts/check-ui-strings.py`로 확인).
- 모든 PR은 CodeRabbit이 자동으로 한국어 리뷰를 남기고, CI를 통과한 뒤 관리자가 검토해 머지합니다. AI 리뷰는 참고용입니다. 처음 기여하는 분의 CI는 관리자 승인 후 시작됩니다.
- 트렌딩 파서를 바꾸면 Python(`pipeline/collect.py`)과 Swift(`TrendingReader.swift`), 공유 픽스처를 함께 고쳐 주세요.
- 바이너리·캐시·API 키·서명 키는 커밋하지 않습니다.
- 기여한 코드는 MIT 라이선스로 배포됩니다.
