# Telegram 채널 플러그인 설치 기록

`telegram@claude-plugins-official` 플러그인을 Claude Code에 붙이면서 정리한
설치 스크립트와, Claude Code on the web(원격 컨테이너) 환경에서 마주친 문제의
진단 기록이다.

## 파일

| 파일 | 용도 |
| --- | --- |
| `setup.sh` | 로컬 머신용 설치·설정 스크립트 |
| `tg-relay.ts` | 이그레스 프록시 환경 전용 우회 릴레이 |
| `server-apiroot.patch` | 릴레이를 쓰기 위한 플러그인 한 줄 패치 |

로컬에 설치할 때 필요한 것은 `setup.sh` 하나뿐이다. 나머지 둘은 프록시 뒤에서만
의미가 있다.

## 로컬 설치

```sh
./setup.sh <BOT_TOKEN>                      # 페어링 절차를 거치는 기본 방식
./setup.sh <BOT_TOKEN> --allow <숫자ID>      # 페어링 없이 바로 사용
./setup.sh <BOT_TOKEN> --no-web-tools        # 웹 도구 허용은 건드리지 않기
```

토큰은 텔레그램에서 [@BotFather](https://t.me/BotFather)에게 `/newbot`을 보내 받는다.
스크립트는 다음을 수행한다.

1. `claude` / `bun` 전제 조건 확인 (MCP 서버가 bun 위에서 동작)
2. 마켓플레이스 추가 + 플러그인 설치 (이미 되어 있으면 건너뜀)
3. `~/.claude/channels/telegram/.env`에 토큰 저장 (권한 600, 기존 키 보존)
4. `~/.claude/settings.json`에 `WebSearch`/`WebFetch` 허용 추가 (아래 참고)
5. `getMe`로 봇 실물 확인

재실행해도 안전하다. 5단계는 실패 원인을 구분해서 알려준다.

| 응답 | 진단 |
| --- | --- |
| 200 | 정상 — 봇 username 출력 |
| 401 | 토큰 무효. **네트워크는 정상** (텔레그램까지 도달함) |
| 404 | 해당 봇 없음 |
| 000 | 연결 실패. **토큰 문제 아님** — 네트워크/이그레스 정책 |

401과 000의 구분이 핵심이다. 401은 서버에 도달했다는 뜻이므로 네트워크는 무죄고,
000은 도달조차 못 했다는 뜻이므로 토큰은 무죄다.

설치 후 페어링:

```
claude --channels plugin:telegram@claude-plugins-official   # 이 플래그 없으면 서버가 연결되지 않음
# 봇에게 DM → 6자리 코드 수신
/telegram:access pair <코드>
/telegram:access policy allowlist                            # 페어링 끝나면 잠글 것
```

`pairing` 정책은 숫자 ID를 확보하기 위한 임시 상태다. 확보한 뒤에는 `allowlist`로
바꿔야 모르는 사람이 페어링 코드를 받아 가지 않는다.

### 페어링을 건너뛰기

페어링의 목적은 숫자 ID 확보뿐이다. ID를 이미 안다면 절차 전체가 불필요하다.

```sh
./setup.sh <BOT_TOKEN> --allow 5046959738          # 여러 명은 쉼표로 구분
```

`access.json`을 `allowlist` 정책으로 직접 쓴다. 기존 파일이 있으면 `.bak`으로
백업한다. 처음부터 잠긴 상태로 시작하므로, `pairing`을 거쳤다가 나중에 잠그는
것보다 노출 창이 없다는 점에서 오히려 안전하다.

본인 ID는 텔레그램에서 [@userinfobot](https://t.me/userinfobot)에게 물어보면 된다.
`@username`이 아니라 숫자다.

`access.json`은 인바운드 메시지마다 다시 읽히므로 정책 변경에 재시작이 필요 없다.
반면 `.env`의 토큰은 서버 부팅 시 한 번만 읽으므로 토큰을 바꾸면 세션을 다시 띄워야
한다.

## 웹 검색 권한

텔레그램으로 "오늘 날씨" 같은 요청을 보내면 세션이 검색을 시도하다 권한에서 막힌다.
채널 세션에는 권한 프롬프트를 띄울 상대가 없기 때문이다 — 사용자는 텔레그램에 있고
프롬프트는 터미널에 뜨므로, 아무도 답하지 않는 채로 요청이 "권한 없음"으로 끝난다.
그래서 도구는 세션이 시작되기 전에 미리 허용돼 있어야 한다.

`setup.sh`의 4단계가 `~/.claude/settings.json`에 이것을 넣는다.

```json
{
  "permissions": {
    "allow": ["WebSearch", "WebFetch"]
  }
}
```

기존 설정은 병합해서 보존하고, 없는 항목만 덧붙인다. 파일을 고치기 전에 `.bak`으로
백업하며, JSON이 깨져 있으면 덮어쓰지 않고 수동 안내만 출력한다. 이미 허용돼 있으면
아무것도 하지 않는다. 건너뛰려면 `--no-web-tools`.

**프로젝트 설정(`.claude/settings.json`)이 아니라 사용자 설정에 쓴다.** 프로젝트
설정은 세션을 띄운 디렉터리에서만 유효해서, 채널 세션을 다른 곳에서 띄우면 같은
증상이 그대로 재발한다. 사용자 레벨이어야 어디서 띄우든 통한다.

`WebFetch`를 같이 넣는 이유는 검색이 두 단계이기 때문이다. `WebSearch`로 결과
목록을 받고 `WebFetch`로 실제 페이지를 열어 읽는데, 앞쪽만 허용하면 두 번째에서
다시 막힌다.

권한 설정은 **세션 시작 시 한 번만 읽힌다.** `access.json`과 달리 재시작이 필요하다.
이미 채널 세션이 떠 있다면 껐다 켜야 적용된다.

파일을 건드리지 않고 한 번만 쓰려면 실행 플래그로도 된다.

```sh
claude --channels plugin:telegram@claude-plugins-official --allowedTools WebSearch WebFetch
```

## 원격 컨테이너에서 마주친 문제

Claude Code on the web 세션에서 이 플러그인을 띄우려다 세 가지 벽을 만났다.
아래는 각각의 원인과 결론이다.

### 1. 이그레스 정책 — 해결됨

`api.telegram.org:443` CONNECT에 게이트웨이가 403을 반환. 환경의 네트워크 접근
수준이 **Trusted**였고 기본 허용 목록에 텔레그램이 없어서였다.

환경 설정에서 **Custom**을 고르고 `api.telegram.org`를 추가하면 해소된다.
"Also include default list of common package managers"를 함께 체크해야 npm/PyPI
등이 끊기지 않는다. 봇 API와 인바운드 파일 다운로드가 같은 호스트를 쓰므로
한 줄이면 충분하다.

### 2. bun TLS — 우회함

정책을 열고 나니 curl은 200을 받는데 플러그인(bun/grammy)만 `ECONNRESET`으로
끊겼다. 원인은 프록시의 도메인별 처리 차이였다.

| 호스트 | 인증서 발급자 | 처리 | bun |
| --- | --- | --- | --- |
| `api.github.com` | CCR Upstream Proxy CA (Anthropic) | TLS 종단(MITM) | 정상 |
| `api.telegram.org` | Go Daddy (실제 텔레그램 인증서) | TCP 패스스루 | 실패 |

bun은 프록시 CA를 이미 신뢰한다(github 200). **CONNECT 터널 위에서 직접 TLS를
맺을 때만** 실패한다 — `200 Connection Established`까지 간 뒤 핸드셰이크에서
리셋된다. 같은 경로에서 curl과 openssl은 정상이다.

배제한 원인: CA 설정 4종(`NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`,
`BUN_CA_BUNDLE_PATH`, `tls.ca`), SNI 유무, HTTP/2 협상, `NO_PROXY` 직접 연결.
설정으로 고칠 수 있는 문제가 아니다. 커스텀 허용 도메인이 패스스루로 처리되는 한
bun 기반 도구 전반에 영향을 준다.

우회는 TLS를 맺는 주체를 bun에서 curl로 옮기는 것이다.

```
플러그인(bun/grammy) → 평문 HTTP → tg-relay → curl(TLS) → api.telegram.org
```

```sh
bun tg-relay.ts 8081 &
export TELEGRAM_API_ROOT=http://127.0.0.1:8081
```

`server-apiroot.patch`는 `TELEGRAM_API_ROOT`가 설정돼 있을 때만 grammy의
`apiRoot`로 넘긴다. 변수가 없으면 원래대로 동작하므로 일반 환경에는 영향이 없다.
플러그인 업데이트 시 패치는 사라진다.

검증: `grammy → 릴레이` 정상, 채널 세션이 MCP `reply` 도구로 실제 발송 성공,
인바운드 롱폴링(`getUpdates`) 유지 확인.

### 3. 대화형 모드 차단 — 해결 못 함

원격 컨테이너의 `claude`는 프롬프트 없이 실행하면 `--print` 입력을 요구한다.
tmux로 PTY를 줘도 마찬가지다. `--input-format stream-json`으로 세션을 상주시켜
보면 브리지는 붙고 롱폴링도 도는데, **채널 메시지가 세션까지 전달되지 않는다** —
stream-json 세션은 stdin으로 들어온 메시지만 처리하고, 채널 주입은 대화형 세션
루프를 통해서만 이뤄지기 때문이다.

결과적으로 인바운드 메시지는 브리지가 소비한 뒤 사라진다. 이 구간을 살릴 방법은
찾지 못했다.

## 결론

원격 컨테이너에서는 **발신은 되지만 실시간 수신 대화는 안 된다.** 1번과 2번은
풀 수 있으나 3번이 남는다. 상시 운영은 로컬에서 해야 하며, 로컬에는 프록시가
없으므로 릴레이도 패치도 필요 없이 `setup.sh`와 `--channels` 플래그만으로 끝난다.

## 운영 메모

- 브리지를 두 개 띄우면 서로 `getUpdates`를 뺏어 메시지가 유실된다. 텔레그램은
  업데이트를 한 소비자에게만 준다. 진단용으로 `getUpdates`를 직접 호출하는 것도
  같은 경쟁을 일으키므로, 브리지가 도는 중에는 호출하지 말 것.
- 토큰은 자격 증명이다. 대화 기록이나 공유되는 로그에 붙여 넣었다면 BotFather
  `/revoke`로 재발급할 것. 이 저장소에는 토큰이 들어 있지 않다.
- 페어링 코드는 숫자 ID를 알아내기 위한 수단일 뿐이다. ID를 이미 알고 있으면
  `access.json`의 `allowFrom`에 직접 넣고 `dmPolicy`를 `allowlist`로 두면 된다.
