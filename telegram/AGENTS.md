<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-08-25 | Updated: 2026-08-25 -->

# telegram

## Purpose
`telegram@claude-plugins-official` 플러그인을 붙이면서 만든 설치 스크립트와,
Claude Code on the web(원격 컨테이너)의 이그레스 프록시 환경에서 겪은 문제의 진단
기록이다. 로컬 설치에 필요한 것은 `setup.sh` 하나뿐이고, 나머지 둘은 프록시 뒤에서만
의미가 있다.

## Key Files
| File | Description |
|------|-------------|
| `README.md` | 설치 절차, 페어링, 401 vs 000 진단표, 프록시 우회 경위 |
| `setup.sh` | 로컬 설치 5단계 스크립트. 재실행 안전 |
| `tg-relay.ts` | bun 의 CONNECT-터널 TLS 버그 우회용 평문 HTTP 릴레이 (기본 8081) |
| `server-apiroot.patch` | 플러그인 `server.ts` 한 줄 패치 — `TELEGRAM_API_ROOT` 로 apiRoot 재지정 |
| `yt.py` | 유튜브 채널/영상 정보 추출기. WebFetch 가 막히는 환경에서 curl + ytInitialData 파싱 |

## Subdirectories
없음.

## For AI Agents

### Working In This Directory
- **401 과 000 의 구분이 이 디렉터리의 핵심 진단 논리다.** `getMe` 가 401 이면 서버에
  도달했다는 뜻이므로 네트워크는 무죄이고 토큰이 잘못된 것이다. 000 이면 도달조차 못 한
  것이므로 토큰은 무죄이고 네트워크/이그레스 정책 문제다. 이 구분을 뭉개는 오류 처리는
  넣지 않는다.
- `setup.sh` 는 `~/.claude/settings.json` 을 건드린다(4단계, 웹 도구 권한).
  기존 키를 보존하는 방식이어야 하며, `--no-web-tools` 로 이 단계를 건너뛸 수 있다.
- 토큰은 `~/.claude/channels/telegram/.env` 에 권한 600 으로 저장된다.
  **토큰 값을 이 디렉터리의 어떤 파일에도 적지 않는다.** 위치만 언급한다.
- `tg-relay.ts` 와 `server-apiroot.patch` 는 짝이다. 릴레이만 띄우고 패치를 적용하지
  않으면 플러그인은 여전히 `api.telegram.org` 로 직접 나간다.
- 페어링 정책은 임시 상태다. 숫자 ID 확보 후 `allowlist` 로 잠가야 한다는 안내를
  README 에서 빼지 않는다.

### Testing Requirements
- `bash -n setup.sh` 로 문법 확인. 스크립트는 재실행 안전하므로 두 번 돌려 본다.
- `setup.sh` 5단계가 실제 연결 검증이다. 별도 테스트 하네스는 없다.
- `yt.py` 는 Python 3 스크립트다. 이 머신의 Python 은 3.13.15
  (`%LOCALAPPDATA%\Programs\Python\Python313`).

### Common Patterns
- 네트워크가 막힌 환경에서는 `curl` 이 통과하는 경우가 많다. `WebFetch`·`bun fetch` 가
  실패하면 curl 로 우회하는 것이 이 디렉터리 전반의 해법이다(`yt.py`, `tg-relay.ts` 둘 다).
- 주석은 우회책의 **배경**을 남긴다. 왜 이런 이상한 코드가 필요했는지가 본문이다.
- 진행 표시는 `==> N/5 <단계명>` 형식.

## Dependencies

### Internal
- `../.claude/settings.json` — `setup.sh` 4단계가 웹 도구 권한을 추가하는 대상

### External
- `claude` CLI, `bun` (MCP 서버 런타임), `curl`
- `grammy` — 플러그인이 쓰는 텔레그램 봇 라이브러리 (`apiRoot` 옵션을 패치가 활용)
- [@BotFather](https://t.me/BotFather) — 봇 토큰 발급

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
