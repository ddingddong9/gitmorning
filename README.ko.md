<p align="center"><img src="https://github.com/ddingddong9/homebrew-gitmorning/releases/download/v0.3.0/icon.png" alt="GitMorning" width="112" /></p>
<h1 align="center">GitMorning</h1>
<p align="center"><strong>다음에 써볼 도구를 발견하세요.</strong><br />AI 없이 시작하는 GitHub Trending 맥 네이티브 앱</p>
<p align="center"><a href="README.md">English</a> · <strong>한국어</strong></p>

---

## GitMorning 소개

주목받는 오픈소스를 발견하고, 어떤 도구인지 읽고, 나중에 써볼 프로젝트를 보관하세요. GitMorning은 GitHub Trending을 세 칸으로 구성한 맥 네이티브 화면에 담습니다.

**기본은 영어 인터페이스와 원문 설명입니다.** 탐색·검색·Star 확인·보관함에는 AI 모델, API 키, 계정이나 구독이 필요하지 않습니다. 각 저장소의 설명은 작성된 언어 그대로 보여주며, 모든 설명을 영어로 자동 번역하지는 않습니다.

## 설치

Homebrew가 설치된 Apple Silicon 맥에서 다음 명령을 실행합니다.

```sh
brew install --cask ddingddong9/gitmorning/gitmorning
```

또는 [최신 릴리스](https://github.com/ddingddong9/homebrew-gitmorning/releases/latest)에서 ZIP을 내려받아 **GitMorning.app**을 응용 프로그램 폴더로 옮기세요.

| 기능 | 필요한 환경 |
| --- | --- |
| 탐색·검색·보관·원문 설명 | macOS 14 이상, Apple Silicon |
| 선택형 한국어 AI 설명 | macOS 26 이상, Apple Intelligence 활성화, 준비된 한국어 지원 모델 |
| 새 데이터·README·앱 업데이트 | 인터넷 연결 |
| 포함된 수집본·이미 저장한 내용 | 오프라인에서도 사용 가능 |

현재는 **개발용 임시 서명된 미공증 미리보기**입니다. 첫 실행 시 macOS 승인이 필요할 수 있습니다. 설치 과정에 보안 우회 명령을 넣지 않습니다. Intel 설치 파일은 아직 없습니다.

## 주요 기능

- **일간·주간 트렌드:** 원본 Trending 순서, 총 Star와 기간 증가량을 확인합니다.
- **AI 없는 설명 읽기:** 저장소의 원문 설명을 즉시 표시합니다.
- **나중에 써볼 도구 보관:** Trending에서 내려간 뒤에도 저장 당시 정보가 남습니다.
- **검색과 언어 선택:** 프로젝트·설명 검색과 제공되는 언어별 수집본을 지원합니다.
- **선택형 한국어 설명:** 원할 때만 README 기반 한국어 AI 설명을 요청합니다.
- **읽기 편한 네이티브 화면:** 라이트·다크 모드와 큰 글자를 제공합니다.
- **앱 안에서 업데이트:** 설치 후 재실행·이번 버전 건너뛰기·나중에 알림을 선택합니다.

수집 시각을 표시합니다. 포함 데이터는 실시간 목록이 아닙니다. HTTPS 데이터 주소를 연결하면 새 수집본을 받을 수 있으며, 없는 기간·언어를 다른 목록으로 대신 표시하지 않습니다.

## 시작하기

1. **Today’s Trending** 또는 **Weekly Trending**을 선택하세요.
2. 프로젝트의 **Original description**을 읽으세요. AI 생성이나 번역은 실행하지 않습니다.
3. **Save**로 보관하거나 **Open on GitHub**로 전체 문서를 확인하세요.

| 단축키 | 동작 |
| --- | --- |
| `⌘F` | 현재 목록 검색 |
| `⌘D` | 보관·해제 |
| `⇧⌘O` | GitHub에서 열기 |
| `⌘R` | 목록 새로고침 |
| `⌘,` | 설정 |

## 한국어 설명은 선택 기능입니다

**Korean explanation · optional AI**를 펼치고 **Explain in Korean**을 누를 때만 맥 내장 모델로 한국어 설명을 생성합니다. README 일부를 쉽게 풀어쓴 설명이며 원문 전체를 문장별로 번역하는 기능은 아닙니다.

유료 LLM API나 클라우드 모델로 자동 전환하지 않습니다. 내장 AI를 지원하지 않아도 기본 탐색에는 문제가 없습니다.

설명은 기기에 저장합니다. **Check README for changes**로 확인한 원문이 같으면 기존 설명을 재사용합니다. 목록은 계속 원문을 표시하며, 설정에서 **Show saved Korean explanations in the list**를 직접 켠 경우에만 저장된 한국어 설명을 목록에 보여줍니다.

AI 설명은 누락이나 오류가 있을 수 있습니다. 생성 시각과 원문 링크를 함께 표시하므로 실행 조건·요금·라이선스는 원문에서 확인해주세요.

## 업데이트

무료 오픈소스 [Sparkle](https://sparkle-project.org/)이 설치 파일의 서명을 검증합니다. 배포 빌드는 자동 확인을 켜고 자동 설치는 끕니다.

- **Install Update / Install & Relaunch:** 내려받기·검증 후 설치하고 다시 실행합니다.
- **Skip This Version:** 해당 버전의 자동 알림을 건너뜁니다.
- **Remind Me Later:** 현재 버전을 유지하고 나중에 다시 확인합니다.

버튼 문구는 업데이트 단계와 macOS 언어에 따라 달라집니다. **GitMorning → Check for Updates…**에서 수동으로 확인하고 설정에서 자동 확인을 끌 수 있습니다.

Homebrew로 직접 업데이트할 수도 있습니다.

```sh
brew update
brew upgrade --cask gitmorning
```

## 개인정보와 비용

보관함과 생성한 설명은 맥에 저장합니다. 계정 동기화·광고·앱 자체 분석 수집은 연결하지 않았습니다. 요청한 데이터와 README는 GitHub에서, 앱 업데이트는 공개 피드에서 가져옵니다.

원문 설명은 AI 없이 표시합니다. 선택형 내장 AI에는 LLM API 사용료가 없습니다. Apple Developer ID 서명·공증은 별도 절차이며 현재 미리보기는 공증되지 않았습니다.

## 자주 묻는 질문

**Apple Intelligence가 꼭 필요한가요?**

선택형 한국어 설명에만 필요합니다. 원문 탐색과 보관에는 필요하지 않습니다.

**원문 설명도 모두 영어인가요?**

인터페이스가 영어 기본입니다. 저장소 설명은 원래 작성된 언어를 유지합니다. 비영어 설명을 영어로 자동 번역하는 기능은 기본 모드에 포함하지 않습니다.

**MIT 라이선스이거나 Apple 인증을 받은 앱인가요?**

현재 앱 자체에 그런 표시를 하지 않습니다. 소스는 비공개이며 코드 라이선스는 아직 선택하지 않았습니다. Sparkle의 MIT 고지는 유지합니다. 코드 라이선스, Sparkle 업데이트 서명, Apple 공증은 서로 다른 절차입니다.

## 피드백

버그 제보나 기능 제안은 [Issues](https://github.com/ddingddong9/homebrew-gitmorning/issues)에 남겨주세요. 공개 배포 저장소에는 Cask·설치 파일·업데이트 피드·사용자 안내만 제공하고 소스는 별도로 관리합니다.

