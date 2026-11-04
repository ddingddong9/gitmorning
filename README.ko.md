<p align="center"><img src="https://github.com/ddingddong9/gitmorning/releases/download/v0.3.0/icon.png" alt="GitMorning" width="112" /></p>
<h1 align="center">GitMorning</h1>
<p align="center"><strong>다음에 써볼 도구를 발견하세요.</strong><br />GitHub Trending을 읽는 맥 네이티브 앱</p>
<p align="center"><a href="README.md">English</a> · <strong>한국어</strong></p>

---

주목받는 오픈소스를 보고, 어떤 도구인지 읽고, 나중에 써볼 프로젝트를 보관하세요. 계정, API 키, 구독이 필요 없습니다.

## 설치

```sh
brew tap ddingddong9/gitmorning https://github.com/ddingddong9/gitmorning
brew install --cask gitmorning
```

또는 [최신 릴리스](https://github.com/ddingddong9/gitmorning/releases/latest)에서 ZIP을 받아 **GitMorning.app**을 응용 프로그램 폴더로 옮기세요.

- macOS 14 이상, Apple Silicon
- 공증 전 미리보기라 첫 실행 때 macOS가 막을 수 있습니다. **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**를 눌러 주세요.

## 기능

- **일간·주간 트렌드:** 원래 순위, 전체 Star, 기간 증가량
- **보관함:** Trending에서 내려가도 저장 당시 정보가 남습니다
- **검색과 언어별 목록:** Python, TypeScript, JavaScript, Swift, Go, Rust
- **한국어 설명 (선택):** 원할 때만 맥 내장 AI로 README를 요약합니다. macOS 26 이상과 Apple Intelligence가 필요합니다
- **라이트·다크 모드, 큰 글자**
- **앱 안에서 업데이트:** 새 버전이 나오면 알려주고, 설치할지 직접 고릅니다

| 단축키 | 동작 |
| --- | --- |
| `⌘F` | 목록 검색 |
| `⌘D` | 보관·해제 |
| `⇧⌘O` | GitHub에서 열기 |
| `⌘R` | 새로고침 |
| `⌘,` | 설정 |

## 업데이트

앱이 자동으로 확인합니다. Homebrew로 설치했다면 이렇게도 업데이트할 수 있습니다.

```sh
brew upgrade --cask gitmorning
```

## 개인정보

보관함, 메모, 설명은 맥에만 저장합니다. 광고나 사용 기록 수집은 없습니다.

## 이 저장소

설치 파일, Homebrew Cask, 앱이 읽는 공용 Trending 데이터(`feed/`, 1시간마다 갱신)를 배포합니다. 앱 소스는 별도로 관리합니다.

버그 제보나 기능 제안은 [Issues](https://github.com/ddingddong9/gitmorning/issues)에 남겨 주세요.
