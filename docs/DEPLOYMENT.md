# 실제 서비스 배포 방향

2026-11-02 수정. 유료 API 없이 시작하며 외부 유료 서비스는 연결하지 않았다.

## 첫 출시 구조

맥 앱에 실제 Trending 수집본을 포함하고 보관함·요약을 기기에 저장한다. 사용자가 요약을 요청하면 GitHub 공식 공개 API에서 README를 읽고 Apple Foundation Models의 온디바이스 모델로 한국어 설명을 만든다. 요약 서버, 관계형 DB, LLM API 키, 구독 티어는 필요하지 않다.

- 목록: 포함 JSON 또는 사용자가 설정한 HTTPS JSON → 맥 앱.
- 요약: 공개 GitHub README → 맥 내장 AI → 로컬 캐시.
- 재사용: README 내용 해시·프롬프트 버전·OS 기반 모델 환경 비교.
- 미지원 환경: 원문과 안내 표시, 유료 모델로 자동 전환하지 않음.

현재 운영 HTTPS 주소와 예약 실행은 설정하지 않았다. 최신 목록 자동 갱신은 후속 작업이다. 제공자를 선택할 때 무료 범위·한도와 지출 차단 수단을 확인하며 결제 서비스나 유료 리소스를 자동 연결하지 않는다.

## 역할과 계층

UI, 수집·요약 로직, 외부 연동, 저장 책임을 코드에서 분리한다. 책임을 나누는 레이어 수와 배포하는 서버 수는 다르다. 5개의 논리 레이어를 두더라도 5대의 서버가 필요한 것은 아니다.

현재 버전은 앱과 공개 데이터 읽기로 시작한다. 예약 수집·데이터 호스팅은 최신 목록 운영 시 추가할 수 있다. 상시 API 서버가 없으므로 전통적인 3-tier 웹앱과 동일한 배치라고 부르지는 않는다.

## DB·API를 추가할 시점

| 요구 사항 | 추가 구성 |
| --- | --- |
| 로그인·여러 기기 보관함 동기화 | 인증, 사용자별 DB와 접근 제어 |
| 과거 순위와 수치의 다양한 조회 | 검색·조회용 DB, 필요 시 API |
| 개인별 추천·읽음 기록 | 사용자 데이터 저장과 추천 처리 |
| 결제·사용량 제한·유료 전용 데이터 | 서버 측 권한 검사, 결제 연동, 비공개 데이터 제공 |
| 사용자 요청에 따른 실시간 AI 분석 | 인증 API, 작업 큐, 요청 제한과 비용 통제 |

요약을 공개 JSON으로 제공하는 버전은 유료 전용 콘텐츠 보호에 적합하지 않다. 유료화를 선택하면 데이터 제공 구조부터 바꾼다.

## 비밀키·비용

요약에는 키와 유료 API가 없다. README 조회는 GitHub 공개 API 한도의 영향을 받는다. 향후 예약 수집에 인증이 필요하면 토큰은 실행 환경의 비밀 저장소에만 두고 앱에 포함하지 않는다.

내장 AI 요약 연산 비용과 앱 공개 배포 비용은 구분한다. GitHub Actions·호스팅의 무료 한도를 초과하거나 Developer ID·App Store 배포를 선택하면 별도 비용이 생길 수 있다. 현재는 로컬 개발 빌드이며 유료 계약·결제 설정은 하지 않는다.

## 앱 배포

현재 앱 번들은 로컬 개발용 임시 서명 상태다. 공개 배포는 Developer ID 서명·공증을 거쳐 DMG/ZIP을 제공하거나 Mac App Store 제출 경로를 선택한다. 웹에서 데이터를 제공하는 것과 앱 설치 파일을 배포하는 것은 별도 작업이다.

## 근거

- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- https://developers.cloudflare.com/r2/buckets/public-buckets/
- https://developers.cloudflare.com/r2/platform/limits/
- https://developer.apple.com/macos/distribution
- https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
