# 개발 방법

- `main`: 확인된 동작을 유지하는 기준 브랜치.
- `feat/<기능>`, `fix/<수정>`, `docs/<문서>`: 작업 브랜치.
- 기능마다 이슈에 목적·완료 조건을 기록하고, PR에 최종 동작과 검증 결과를 적는다.
- 작은 변경 단위로 `feat:`, `fix:`, `docs:`, `test:`, `chore:` 커밋을 남긴다.
- PR은 CI 확인 후 병합한다. AI는 사용자 지시 없이 자동 병합하지 않는다.
- 앱 바이너리·캐시·API 키·로컬 환경설정은 커밋하지 않는다.
- 테스트 데이터는 실제 수집 결과와 구분한다. 외부 네트워크가 필요한 검증은 CI의 단위 테스트와 분리한다.

## 검증

```sh
python3 -m unittest discover -s pipeline/tests -v
swift test --disable-sandbox
zsh scripts/build-app.sh
```

XCTest가 없는 Command Line Tools 환경에서는 [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)의 `check-*.swift` 절차를 사용한다. 기여한 코드는 저장소의 MIT 라이선스로 배포된다.
