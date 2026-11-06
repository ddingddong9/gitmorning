# GitMorning for macOS

GitHub Trending을 한국어로 읽는 Mac 네이티브 앱입니다. 실제 수집본 탐색·보관·HTTPS 읽기와 맥 내장 AI를 이용한 무료 한국어 요약을 제공합니다. 운영 데이터 주소와 공개 앱 배포는 아직 설정하지 않았습니다.

## 현재 동작

- 실제 GitHub Trending의 일간·주간 목록과 원본 순위, 총 Star·기간 증가 표시.
- 앱에 검증된 전체 언어 수집본을 포함하므로 서버 주소 없이도 시작합니다. 포함 데이터는 실시간 조회가 아니며 수집 시각을 표시합니다.
- 현재 목록 검색, 기기 내 보관함, 기본 브라우저에서 GitHub 원문 열기.
- 보관한 저장소는 현재 Trending과 독립적으로 저장 당시 설명·지표·수집 시각을 유지합니다.
- HTTPS JSON 폴더 주소를 설정하면 시작·기간/언어 전환·새로고침에서 해당 수집본을 조회합니다.
- 기간·언어가 다른 응답, 손상 JSON, 이전 시각의 응답은 정상 캐시를 교체하지 않습니다. 필터가 바뀌면 늦은 응답을 무시합니다.
- 상세 화면의 ‘맥에서 무료 요약’으로 공개 README를 가져와 기기에서 한국어 설명을 생성합니다. 외부 LLM API·키·구독은 사용하지 않습니다.
- 생성한 요약은 기기에 저장됩니다. ‘README 변경 확인’은 문서 해시가 같으면 다시 생성하지 않습니다. 원문 소개·프롬프트 버전·OS 기반 모델 환경이 달라지면 캐시를 갱신합니다.
- 내장 AI 미지원·비활성·모델 준비 중·한국어 미지원 환경에서는 이유를 안내하고 원문을 유지합니다. 취소·오류 시 기존 요약을 지우지 않습니다.
- 본문 16pt·목록 설명 15pt·보조 정보 13pt, ‘크게’ 모드는 본문 18pt. 라이트·다크·시스템 모드를 지원하고 설정을 유지합니다.
- 처음에는 화면 가운데 약 1060×748pt 창으로 실행합니다.

## 실행과 빌드

기본 탐색은 macOS 14 이상입니다. 내장 AI 요약에는 macOS 26 이상, Apple Intelligence를 지원하고 활성화한 맥, 준비된 한국어 지원 모델이 필요합니다. 요약을 포함한 소스 빌드에는 macOS 26 SDK를 제공하는 Xcode 26 이상의 개발 도구가 필요합니다. 이전 SDK로 빌드하면 원문 탐색만 제공합니다. 이 작업 환경의 실행 파일은 Apple Silicon용입니다.

```sh
zsh scripts/build-app.sh
open dist/GitMorning.app
```

소스의 `Sources/GitMorning/Resources/Snapshots`는 2026-11-02에 CI에서 실제 수집·검증한 일간 17개·주간 16개 저장소를 포함합니다. CI 앱 빌드는 이 경로를 빌드 시점의 새 수집본으로 갱신합니다. 로컬 빌드는 체크아웃된 포함 데이터로 오프라인 빌드할 수 있습니다.

현재 앱은 로컬 개발 서명이며 Developer ID 서명·공증과 App Store 배포는 하지 않았습니다.

## 무료 요약 동작

README는 GitHub 공식 API에서 인증 없이 읽으므로 인터넷 연결과 공개 API 요청 한도의 영향을 받습니다. 생성은 명시적으로 `SystemLanguageModel.default` 온디바이스 모델을 사용하며 Private Cloud Compute나 외부 AI로 자동 전환하지 않습니다. 원문 일부(코드 블록·이미지 줄 제외, 최대 4,500자·UTF-8 6,000바이트)만 입력하므로 누락·오류가 있을 수 있습니다. 생성 시각·원문 링크를 함께 표시합니다. 캐시는 오프라인으로 읽을 수 있으며 README 변경 여부는 버튼을 눌러 확인합니다.

내장 모델의 정확한 리비전은 노출되지 않아 OS 버전을 모델 환경 키로 사용합니다. 같은 OS에서 모델만 업데이트된 경우 자동 감지하지 못할 수 있습니다. 10개 실제 저장소 품질 평가는 아직 남아 있습니다.

## 데이터 갱신 주소

설정 → 데이터 갱신에서 JSON을 제공하는 HTTPS 폴더 주소를 입력하고 ‘주소 적용’을 누릅니다.

```text
https://data.example.com/snapshots/daily-all.json
https://data.example.com/snapshots/weekly-all.json
https://data.example.com/snapshots/daily-python.json
```

위 주소는 구조 설명용 예시입니다. 실제 운영 주소는 아직 없습니다. 설정에는 파일명이 아닌 폴더 주소를 입력합니다. 인증 정보·쿼리·fragment가 포함된 주소와 HTTP 주소는 받지 않습니다. 비워두면 포함 데이터와 로컬 캐시를 읽습니다.

언어별 Trending은 별도 스냅샷입니다. 포함 데이터에 없는 언어를 선택하면 수집본 없음 상태가 표시되며, 전체 목록을 필터링해 해당 언어의 공식 Trending이라고 표시하지 않습니다. 보관함의 언어 필터는 기기에 저장한 항목을 필터링합니다.

네트워크 주소는 URLSession으로 읽고 리다이렉트·비정상 HTTP·3MB 초과 응답을 거부합니다. 연결 실패 시 마지막 정상 데이터와 수집 시각을 유지합니다.

## 프로젝트 구조

| 경로 | 역할 |
| --- | --- |
| Sources/GitMorning | SwiftUI 화면, 앱 상태, 설정, 포함 수집본 |
| Sources/GitMorningCore | 데이터 계약·HTTPS 읽기·캐시·보관함 모델 |
| pipeline | Python 수집기와 테스트 |
| .github/workflows | Python·Swift 테스트, 실제 수집, 앱 빌드 |
| Resources | 아이콘·번들 설정 |
| scripts | 빌드·핵심 로직·데이터 계약 검증 |

## 검증

```sh
python3 -m unittest discover -s pipeline/tests -v
swift test --disable-sandbox
```

XCTest가 없는 Command Line Tools 환경의 보조 검증:

```sh
mkdir -p .build
swiftc -module-cache-path .build/core-check-cache Sources/GitMorningCore/*.swift scripts/check-core.swift -o .build/check-core
.build/check-core
python3 -m pipeline.collect --html pipeline/tests/fixtures/trending.html
swiftc -module-cache-path .build/core-check-cache Sources/GitMorningCore/TrendSnapshot.swift Sources/GitMorningCore/SnapshotDate.swift scripts/check-contract.swift -o .build/check-contract
.build/check-contract pipeline/output/daily-all.json
```

Python 테스트는 수집 파싱·순위·누락 지표·실패 보존을 확인합니다. Swift 테스트는 검색·보관, 기간/언어 불일치, 이전 응답 거부, HTTPS 주소 검증, HTTP 오류와 응답 검증, 저장소 정보 유지까지 확인합니다. 외부 수집 CI는 합성 HTML 테스트와 별도로 실제 일간·주간 페이지를 조회합니다.

CI는 PR에서만 실행합니다(main에는 PR로만 들어가므로 머지 후 재실행하지 않음, 필요하면 Actions에서 수동 실행). macOS 작업은 `Sources/`, `Tests/`, `Resources/`, `scripts/`, `pipeline/`, `Package.*`, `ci.yml` 중 하나가 바뀐 PR에서만 돕니다. 비공개 저장소에서 macOS 실행은 무료 제공량을 10배로 차감하기 때문입니다. 문서·다른 워크플로만 바꾼 PR은 Ubuntu 작업만 실행합니다.

## 로컬 저장

`~/Library/Application Support/GitMorning/` 아래에 정상 수집본 캐시(`snapshots/`), 요약(`summaries/`)과 보관함(`saved-catalog-v1.json`)을 저장합니다. 이전 프로토타입의 `bookmarks.json`은 보존하며 샘플 ID를 실제 저장소로 표시하지 않습니다. 화면·글자·데이터 주소 설정은 앱 UserDefaults에 저장합니다.

## 앱 설치와 업데이트

Sparkle 2.10.1 공식 바이너리는 SwiftPM이 가져옵니다. 네트워크가 없는 로컬 환경에서 탐색·요약 개발만 하려면 `GITMORNING_CORE_ONLY=1 zsh scripts/build-app.sh`를 사용합니다. 이 빌드는 업데이트 기능을 포함하지 않으며 공개 릴리스가 거부됩니다.

Homebrew Cask·서명된 appcast·설치 파일 준비는 [배포 가이드](RELEASING.md)를 참고하세요.

## 다음 단계

- 실제 README 10개를 대상으로 한국어 요약의 사실성·누락·가독성 평가.
- 운영 HTTPS 저장소에 JSON·매니페스트 배포, 실패 감시 후 예약 실행.
- 실제 언어별 수집본 운영 검증.
- 공개 배포용 서명·공증·업데이트.

개발 규칙: [CONTRIBUTING.md](../CONTRIBUTING.md). 배포 설계: [DEPLOYMENT.md](../DEPLOYMENT.md). 수집기: [pipeline/README.md](../pipeline/README.md). 작업 목록: [ROADMAP.md](../ROADMAP.md).

## Claude Code 스킬

`.claude/skills/`에는 이 프로젝트용 Claude Code 스킬이 들어 있습니다. 외부 MIT 저장소에서 내용을 검토한 뒤 복사했으며, 각 폴더에 원본 LICENSE를 함께 둡니다. OpenAI 에이전트 설정·이미지는 제외했습니다.

| 스킬 | 출처 | 커밋 | 용도 |
| --- | --- | --- | --- |
| `swiftui-pro` | [twostraws/SwiftUI-Agent-Skill](https://github.com/twostraws/SwiftUI-Agent-Skill) | `f2920b6` | SwiftUI 코드 리뷰 |
| `swift-concurrency` | [AvdLee/Swift-Concurrency-Agent-Skill](https://github.com/AvdLee/Swift-Concurrency-Agent-Skill) | `d577081` | 동시성·Swift 6 전환 |
| `macos-spm-app-packaging` | [Dimillian/Skills](https://github.com/Dimillian/Skills) | `05ba982` | SwiftPM 앱 패키징·서명·공증 참고 (bootstrap·키체인 스크립트 제외) |

업데이트할 때는 원본 저장소의 변경 내용을 읽고 확인한 뒤 다시 복사하고 위 커밋을 갱신합니다.

## 화면 스냅샷 (디버그 빌드 전용)

화면 기록 권한 없이 UI를 확인할 때 사용합니다. 디버그 빌드 실행 파일을 `.app` 번들 안에 넣고 실행하면 메인 창과 아침 브리핑 패널을 PNG로 저장한 뒤 종료합니다. 릴리스 빌드에는 포함되지 않습니다(`#if DEBUG`).

```sh
GITMORNING_SNAPSHOT_DIR=/tmp/gitmorning-shots GitMorning.app/Contents/MacOS/GitMorning -readingSize Large -appearance Dark
```

`-readingSize`, `-appearance`, `-interfaceLanguage` 같은 실행 인자는 저장된 설정을 바꾸지 않고 그 실행에만 적용됩니다.
