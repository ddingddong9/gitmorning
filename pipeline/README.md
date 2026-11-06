# Trending 수집기

Python 3.9+ 표준 라이브러리만 사용합니다. 원본 순위와 기간별 증가 수치를 유지하며, 목록이 비거나 손상되면 기존 결과를 교체하지 않습니다. 템플릿·폼·다이얼로그는 저장소 설명으로 읽지 않습니다. 로그인 세션·쿠키는 사용하지 않습니다.

```sh
python3 -m unittest discover -s pipeline/tests -v
python3 -m pipeline.collect --period daily --language all
python3 -m pipeline.collect --period weekly --language Python
python3 -m pipeline.collect --html pipeline/tests/fixtures/trending.html
```

마지막 명령은 네트워크 없이 합성 HTML을 검증하는 예시이며 실제 Trending 데이터가 아닙니다. 출력은 `pipeline/output/daily-all.json` 등으로 생성되고 Git에서는 제외합니다. 이 경로를 아직 운영 주소로 공개하지 않았습니다.

`--readmes`는 공식 API로 README 소스와 SHA도 수집합니다. `GITHUB_TOKEN`은 환경변수에서 읽으며 API 호스트에만 보냅니다. README 수집 실패는 항목별로 표시합니다. AI 모델 호출은 구현하지 않았고 `summaryStatus: pending`으로 기록합니다.

## 데이터 계약 v1

스냅샷: `schemaVersion`, `period`, `languageFilter`, `sourceURL`, `collectedAt`(UTC ISO8601), `status`, `repositories`.

항목: `id`(owner/name), `owner`, `name`, `url`, `rank`, `description`, `language`, `stars`, `periodStars`, `summaryStatus`. 미확인 지표와 언어는 null입니다. 영문 설명을 한국어 요약이라고 표시하지 않습니다.

공유 피드는 일간 목록마다 `history-daily-<language>.json`도 발행합니다(`pipeline/history.py`). 최근 14일(UTC 날짜) 동안 저장소별 순위를 담고, 같은 날 여러 번 수집하면 그날의 마지막 목록으로 바꿉니다. 형식이 맞지 않는 이전 파일은 무시하고 새로 시작합니다. 앱은 이것으로 연속 트렌딩 일수와 순위 흐름을 보여 줍니다.

공유 피드(`feed/build_site.py`)는 항목마다 선택 필드 `readmeExcerpt`를 추가합니다. `readme_excerpt()`가 README에서 배지·로고·제목·목록·표·코드·인용·링크 모음과 설명 반복을 건너뛰고 처음 나오는 설명 문단 1~2개를 최대 320자로 뽑은 원문 발췌이며, AI 요약이 아닙니다. 피드 작업의 `GITHUB_TOKEN`으로 읽고 `v1/readmes.json`에 ETag로 캐시하므로 바뀌지 않은 README는 요청 한도를 쓰지 않습니다. 읽기 실패는 이전 발췌를 유지하고 발행을 막지 않습니다. 앱은 설명이 없으면 발췌를 설명 대신, 있으면 "README에서" 섹션으로 보여 주며 같은 기기 내 번역을 씁니다. 이 필드가 없는 이전 피드와 GitHub 직접 읽기는 그대로 동작합니다.

일간·주간과 언어별 목록은 각각 다른 페이지를 수집해야 합니다. 전체 목록에서 Python만 골라낸 결과를 Python Trending이라고 부르지 않습니다. HTTP 성공·HTML 파싱 성공이 원본 전체의 완전성을 완전히 보장하지는 않으므로 항목 수 급변 감시는 후속 작업입니다.

## 앱 파서와의 일치

앱의 `Sources/GitMorningCore/TrendingReader.swift`도 같은 페이지를 직접 읽습니다. 두 파서는 아래 규칙을 똑같이 따르고, 공통 테스트 데이터 `pipeline/tests/fixtures/parity/`로 고정합니다. 한쪽을 바꾸면 다른 쪽도 함께 바꾸세요.

- 무시: `script`·`style`·`template`·`dialog`·`form` 태그, `hidden` 속성, `aria-hidden="true"`.
- 엔티티: 숫자 참조와 세미콜론으로 끝나는 HTML5 이름 참조를 한 번만 해석합니다. Swift 표는 `python3 scripts/generate-html-entities.py`로 생성합니다.
- 속성: 같은 이름이 반복되면 첫 값을 사용하고, 따옴표 안의 `>`는 태그 끝이 아닙니다.
- 지표: 숫자·쉼표·공백 외 형식(예: `12.3k`)은 0이 아니라 null입니다. 저장소 제목 누락·중복(대소문자 무시)·빈 목록은 전체를 거부합니다.

```sh
python3 -m unittest discover -s pipeline/tests -v
swiftc Sources/GitMorningCore/*.swift scripts/check-parity.swift -o .build/check-parity && .build/check-parity
```

CI는 실제 일간·주간 페이지를 한 번씩 받아 두 파서 결과가 같은지 비교합니다. `trending-canary` 워크플로는 하루 네 번(07:17·13:17·19:17·01:17 KST, GitHub가 예약 실행을 건너뛸 때를 대비) 실제 페이지와 공유 피드 신선도를 확인해 항목 수가 5개 미만이거나 Star·증가량·언어 인식률이 80% 미만이면 `trending-canary` 이슈를 열거나 댓글을 남깁니다(`python3 -m pipeline.canary`).

## 공용 데이터 배포

`publish-trending` 워크플로가 매시 실행되도록 예약돼 전체 14개 목록을 수집해 GitHub Pages(`https://ddingddong9.github.io/gitmorning/v1/`)에 올립니다. `feed/build_site.py`가 이 폴더의 `collect.py`를 그대로 가져다 씁니다. GitHub가 예약 실행을 몇 시간 간격으로만 돌려서(5~8시간 관찰) 앱은 8시간 이내 데이터를 사용하고, 그보다 오래됐거나 받을 수 없으면 GitHub를 직접 읽습니다.

## 운영 전 남은 일

1. GitHub Actions의 수동 수집을 실제 네트워크에서 검증.
2. 원문 기반 한국어 요약 생성, 문서 해시·모델·프롬프트 버전 캐시.
3. 객체 저장소에 버전별 JSON 업로드, 마지막 정상 매니페스트 교체.
4. 앱에 HTTPS 읽기 공급자와 로컬 캐시 연결.
5. 실패 감시를 확인한 뒤 예약 실행 활성화.
