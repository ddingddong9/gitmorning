# Homebrew와 앱 업데이트 배포

소스·Cask·공유 피드·릴리스가 모두 공개 저장소 `ddingddong9/gitmorning` 하나에 있습니다(2026-11-06 오픈소스 전환 전에는 소스를 비공개 `gitmorning-app`에 두었습니다). 배포 전용 공개 저장소는 생성했습니다. 0.3.0과 영어 기본 0.4.0 릴리스, Homebrew Cask를 발행했습니다.

## 사용자 경험

```sh
brew tap ddingddong9/gitmorning https://github.com/ddingddong9/gitmorning
brew trust ddingddong9/gitmorning   # Homebrew 7+
brew install --cask gitmorning
```

앱의 Sparkle 표준 업데이트 창이 새 버전·릴리스 노트를 표시합니다. 사용자가 설치·재실행, 이번 버전 건너뛰기, 나중에 알림을 선택합니다. 단계·시스템 언어에 따라 버튼 이름이 달라집니다. 메뉴의 ‘업데이트 확인…’은 건너뛴 버전도 직접 확인할 수 있습니다.

Sparkle에 버전 비교·건너뛰기 저장·서명 검증·다운로드·설치·재실행을 맡깁니다. 앱을 덮어쓰는 자체 shell 스크립트는 사용하지 않습니다. 앱 기본 설정은 자동 확인 켜짐·자동 설치 꺼짐·시스템 정보 전송 꺼짐입니다.

## 자동 릴리스 (권장)

태그를 푸시하면 GitHub Actions가 빌드·서명·초안 Release까지 만들고, 게시하면 Cask PR을 엽니다. 비용은 0원입니다(공개 저장소의 Actions·macOS 러너·환경 승인은 무료, Apple Developer ID 없음).

```text
릴리스 노트 PR 머지 → git tag v0.5.7 && git push origin v0.5.7
  → release.yml (release 환경, 승인 필요)
      태그가 main 위인지 · 버전이 공개 버전보다 높은지 확인 · 빌드 번호 = 공개 appcast + 1
      최신 공유 목록 포함 빌드 → 개인키로 ZIP 서명 → appcast·SHA256SUMS → 초안 Release
  → (직접) 초안 확인 후 게시  ← 이 순간 사용자에게 업데이트가 보임
  → release-cask.yml: Cask(version·sha256)와 distribution/ 기록을 바꾸는 PR → CI 통과 후 머지
```

### 키는 어디서 쓰이나

- **개인키** (`SPARKLE_PRIVATE_KEY`, `release` 환경 Secret): 서명 단계에서만 임시 파일(권한 600)로 꺼냈다가 바로 지웁니다. 저장소·로그·산출물에 남지 않습니다. 이 키가 있어야만 기존 앱이 받아들이는 업데이트를 만들 수 있습니다.
- **공개키** (`distribution/sparkle-public-key.txt`, 앱 `Info.plist`의 `SUPublicEDKey`): 공개돼도 안전합니다. 워크플로는 Secret에서 공개키를 다시 계산해 이 파일과 다르면 중단합니다. 잘못된 키로 서명하면 모든 사용자의 업데이트가 실패하기 때문입니다.
- **앱의 검증:** Sparkle이 HTTPS로 appcast와 ZIP을 받고, 압축을 풀기 전에 ZIP의 Ed25519 서명을 앱에 들어 있는 공개키로 확인합니다. 맞지 않으면 설치하지 않습니다. Apple 공증과는 별개라, 공증 없이도 업데이트 위조를 막습니다.
- **새 키를 만들지 마세요.** 기존 사용자 앱에는 지금 공개키만 들어 있어서, 다른 키로 서명한 업데이트는 모두 거부됩니다. 키를 잃으면 사용자가 직접 새로 설치해야 합니다. 개인키를 안전한 곳에 따로 백업하세요.

### appcast 위치

`https://github.com/ddingddong9/gitmorning/releases/latest/download/appcast.xml` (최신 Release의 첨부 파일)을 유지합니다. 모든 사용자 앱에 이 주소가 들어 있고, Release를 게시하는 순간 ZIP과 appcast가 함께 바뀌어 초안 단계에서는 아무것도 공개되지 않습니다. Pages나 raw URL은 Release와 공개 시점이 따로 놀고 주소를 바꾸면 기존 앱이 따라오지 못합니다.

### 한 번만 하는 설정

1. **`release` 환경:** Settings → Environments → New environment `release` → Required reviewers에 본인 → Deployment branches and tags: Selected, 태그 규칙 `v*`.
2. **개인키 Secret** (내용이 화면에 나오지 않음):
   ```sh
   gh secret set SPARKLE_PRIVATE_KEY --env release --repo ddingddong9/gitmorning < .release-secrets/sparkle-ed25519.key
   ```
3. **Cask PR 토큰:** Settings → Developer settings → Fine-grained personal access tokens → Repository access: `ddingddong9/gitmorning`만 → Permissions: Contents Read and write, Pull requests Read and write → 만료 1년. 기본 `GITHUB_TOKEN`으로 연 PR에서는 CI가 돌지 않아 보호 규칙의 필수 검사가 끝나지 않으므로 별도 토큰이 필요합니다.
   ```sh
   gh secret set CASK_PR_TOKEN --repo ddingddong9/gitmorning
   ```

### 릴리스할 때마다

1. `distribution/release-notes.md`의 첫 줄을 `GitMorning 0.5.7 — 제목` 형식으로 쓰고 PR로 머지합니다(워크플로가 버전과 첫 줄을 대조합니다).
2. `git tag v0.5.7 && git push origin v0.5.7` → Actions에서 `release` 환경 승인.
3. 초안 Release를 확인하고 게시합니다.
4. 자동으로 열린 "chore: update the cask to 0.5.7" PR을 CI 통과 후 머지합니다.

아래 1~5는 같은 과정을 로컬에서 직접 하는 방법입니다(워크플로를 쓸 수 없을 때).

## 1. 의존성 준비

macOS 26 SDK와 Swift 개발 도구가 필요합니다. `Package.swift`가 Sparkle **2.10.1** 공식 SwiftPM 바이너리와 SHA-256을 고정합니다. SwiftPM이 HTTPS로 다운로드해 검증합니다. 앱 번들에는 Sparkle과 helper·라이선스를 모두 보존합니다.

네트워크가 제한된 환경에서는 공식 릴리스의 `Sparkle-for-Swift-Package-Manager.zip`을 받아 체크섬을 확인한 뒤 `.sparkle/`에 추출할 수 있습니다.

```text
공식 URL: https://github.com/sparkle-project/Sparkle/releases/tag/2.10.1
ZIP SHA-256: 4c2e48a3e50ebcc2c88a58a4c7264a1a99c3c31857ce754357afb9cdb323022a
```

추출한 XCFramework의 **패키지 내 상대 경로**를 `GITMORNING_SPARKLE_XCFRAMEWORK`에 지정하면 로컬 빌드에서 사용합니다. 출처·버전을 확인하지 않은 다른 앱의 프레임워크를 공개 릴리스에 사용하지 마세요.

`GITMORNING_CORE_ONLY=1`은 개발용 대안으로 내장 AI·탐색 UI만 빌드합니다. 업데이트가 빠진 이 빌드는 공개 배포 스크립트가 거부합니다.

## 2. 업데이트 서명 키

Sparkle 업데이트 인증에는 무료 Ed25519 키를 사용합니다. Apple Developer ID 비용과 별개입니다. 키 파일은 `.release-secrets/`에만 저장하며 Git과 설치 ZIP에 포함하지 않습니다. 스크립트는 32바이트 seed를 Base64로 저장하는 Sparkle 2.10 형식을 사용합니다.

```sh
swiftc -module-cache-path .build/signing-cache scripts/release-signing.swift -o .build/release-signing
.build/release-signing prepare-key .release-secrets/sparkle-ed25519.key
```

명령은 **공개키만** 출력합니다. 개인키는 권한 600, 폴더는 700으로 만듭니다. 기존 키를 덮어쓰지 않습니다. 이 키를 안전한 별도 위치에 백업하세요. Developer ID 없는 배포는 키를 잃으면 기존 사용자에게 인증된 업데이트를 이어갈 수 없습니다.

## 3. 배포용 앱 빌드

아래 주소는 이 저장소를 기준으로 합니다. 최신 피드와 설치 ZIP은 공개 GitHub Release에서 제공합니다.

```sh
export GITMORNING_VERSION=0.4.0
export GITMORNING_BUILD=4
export GITMORNING_RELEASE=1
export GITMORNING_UPDATE_FEED=https://github.com/ddingddong9/gitmorning/releases/latest/download/appcast.xml
export GITMORNING_UPDATE_PUBLIC_KEY="$(.build/release-signing public-key .release-secrets/sparkle-ed25519.key)"
zsh scripts/build-app.sh
```

`CFBundleVersion`은 릴리스마다 증가시킵니다. 버전은 `major.minor.patch`, 빌드는 양의 정수입니다. 피드와 공개키는 항상 함께 설정하며 잘못된 URL·키·업데이터 없는 릴리스는 거부합니다. 현재 번들 ID를 유지해 기존 보관함을 보존합니다.

기본 코드는 무료 개발용 ad-hoc 서명입니다. Homebrew Cask는 sha256으로 받은 ZIP을 확인한 뒤 `postflight`에서 앱의 다운로드 격리 표시(`com.apple.quarantine`)를 재귀적으로 지웁니다. 그래서 Homebrew 설치는 첫 실행 경고가 뜨지 않습니다. 재귀(`-dr`)여야 Sparkle 내부 도우미도 실행됩니다. ZIP을 직접 받은 경우는 지우지 않으므로 첫 실행 때 Gatekeeper 승인(그래도 열기)이 필요합니다. 그 밖의 서명·공증 우회는 넣지 않습니다. Developer ID와 공증을 선택할 경우 사용자 명시 설정 후 별도 비용으로 진행합니다. 자동 업데이트 인증은 어떤 경우든 Ed25519로 검증합니다.

## 4. 릴리스 파일 생성

릴리스 노트를 작성한 뒤 다음을 실행합니다. 네트워크 업로드는 하지 않습니다.

```sh
python3 scripts/prepare-release.py \
  --repository ddingddong9/gitmorning \
  --key-file .release-secrets/sparkle-ed25519.key \
  --notes distribution/release-notes.md \
  --output .release-local/v0.4.0
```

생성물:

- `GitMorning-0.4.0-arm64.zip`: 앱 하나와 번들 내부 리소스만 포함.
- `appcast.xml`: 버전·최소 macOS·arm64 조건·Ed25519 서명·실제 파일 크기.
- `SHA256SUMS`: 설치 ZIP의 SHA-256.
- `Casks/gitmorning.rb`: 실제 SHA-256과 버전 고정, `auto_updates true`, Sparkle livecheck.
- `release.json`: 공개 메타데이터. 개인키를 포함하지 않음.

배포 스크립트는 실제 앱의 피드·공개키·서명·아키텍처를 검사합니다. 기존 설치 ZIP을 덮어쓰지 않습니다. 같은 버전의 다른 ZIP을 재발행하지 마세요.

## 5. 검토 후 공개

1. 이 저장소에 GitHub Release `v0.4.0` 초안을 만듭니다. `distribution/release-notes.md`·`distribution/appcast.xml`은 같은 PR에서 갱신합니다.
2. 검증된 ZIP, `appcast.xml`, `SHA256SUMS`를 첨부합니다. 개인키·소스 작업 폴더는 첨부하지 않습니다.
3. 앱을 설치한 별도 테스트 환경에서 공개 피드 조회·Ed25519 검증을 확인합니다.
4. Release를 발행한 뒤 생성된 Cask를 루트 `Casks/gitmorning.rb`에 반영합니다(Homebrew tap이 이 경로를 읽습니다). `main`은 보호돼 있어 직접 푸시할 수 없으니, Cask 변경도 PR로 올리고 CI 통과 후 머지합니다. 기존 사용자에게는 Release의 최신 appcast가 갱신되어 전달됩니다.
5. 익명 HTTPS 다운로드와 아래 명령을 검증한 후 README의 배포 준비 중 표시를 제거합니다.

```sh
brew tap ddingddong9/gitmorning https://github.com/ddingddong9/gitmorning
brew trust ddingddong9/gitmorning   # Homebrew 7+
brew info --cask gitmorning
brew install --cask gitmorning
```

공개 저장소 이름에 `homebrew-` 접두사가 없으므로 tap에는 저장소 URL을 함께 적어야 합니다. Homebrew 7부터는 외부 tap의 Cask를 불러오기 전에 `brew trust`로 한 번 신뢰해야 합니다(2026-11-04 확인).

일반 `brew upgrade`는 앱 자체 업데이트 여부를 고려합니다. 사용자가 명시적으로 `brew upgrade --cask gitmorning`을 실행할 수도 있습니다. `zap`이나 보관함 삭제는 기본 제거 동작에 넣지 않습니다.

## 6. 업데이트 검증

첫 설치만으로는 검증이 끝나지 않습니다. **이전 빌드 3 → 다음 빌드 4**로 다음을 모두 확인한 후 일반 배포합니다.

- 자동 알림·수동 확인·업데이트 없음·연결 실패.
- Skip This Version 후 같은 버전 자동 알림 제외, 다음 버전 알림.
- 다운로드 취소와 재시도.
- Install Update → 서명 검증 → Install & Relaunch → 실제 번들 버전 증가.
- 개인 설정·보관함·기존 요약 유지.
- 손상 ZIP·다른 키 서명 거부, 이전 버전으로 다운그레이드하지 않음.

정식 Sparkle 2.10.1 ZIP의 공식 SHA-256 일치를 확인했고 실제 업데이터가 포함된 앱 빌드·서명·실행과 설정 활성화를 검증했습니다. 공개 피드에서 실제 0.3.0 → 0.4.0 업데이트, 건너뛰기 저장, 수동 재확인, 다운로드·설치·재실행과 버전 증가를 검증했습니다. 새 맥에서 Homebrew 최초 설치와 Gatekeeper 검증은 별도 항목입니다. 사용자에게 설치 가능하다고 알리기 전에 이 절차를 완료해야 합니다.

## 근거

- https://sparkle-project.org/documentation/
- https://sparkle-project.org/documentation/programmatic-setup/
- https://sparkle-project.org/documentation/publishing/
- https://docs.brew.sh/Cask-Cookbook
