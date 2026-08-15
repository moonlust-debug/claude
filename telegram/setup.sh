#!/usr/bin/env bash
# Telegram 채널 로컬 설정 — 본인 머신에서 실행하세요.
#
# 사용법:
#   ./telegram-setup.sh <BOT_TOKEN>
#
# 토큰은 텔레그램에서 @BotFather 에게 /newbot 을 보내 발급받습니다.
# (형식: 123456789:AAH... — 숫자 접두사 + 콜론 + 문자열)

set -euo pipefail

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  echo "오류: 봇 토큰을 인자로 넘겨주세요." >&2
  echo "사용법: $0 <BOT_TOKEN>" >&2
  exit 1
fi

if ! printf '%s' "$TOKEN" | grep -qE '^[0-9]+:[A-Za-z0-9_-]+$'; then
  echo "오류: 토큰 형식이 BotFather 토큰과 다릅니다 (예: 123456789:AAH...)." >&2
  exit 1
fi

STATE_DIR="${TELEGRAM_STATE_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/channels/telegram}"

echo "==> 1/4  전제 조건 확인"
command -v claude >/dev/null || { echo "claude CLI 가 없습니다. https://claude.com/claude-code 참고" >&2; exit 1; }
if ! command -v bun >/dev/null; then
  echo "bun 이 없습니다. MCP 서버가 bun 위에서 동작합니다. 설치:" >&2
  echo "  curl -fsSL https://bun.sh/install | bash" >&2
  exit 1
fi
echo "    claude: $(claude --version)"
echo "    bun:    $(bun --version)"

echo "==> 2/4  마켓플레이스 + 플러그인 설치"
claude plugin marketplace add anthropics/claude-plugins-official || true
claude plugin install telegram@claude-plugins-official || true
claude plugin list | sed -n '1,12p'

echo "==> 3/4  토큰 저장 → $STATE_DIR/.env"
mkdir -p "$STATE_DIR"
if [ -f "$STATE_DIR/.env" ] && grep -q '^TELEGRAM_BOT_TOKEN=' "$STATE_DIR/.env"; then
  # 기존 키는 보존하고 토큰 줄만 교체
  grep -v '^TELEGRAM_BOT_TOKEN=' "$STATE_DIR/.env" > "$STATE_DIR/.env.tmp" || true
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" >> "$STATE_DIR/.env.tmp"
  mv "$STATE_DIR/.env.tmp" "$STATE_DIR/.env"
else
  printf 'TELEGRAM_BOT_TOKEN=%s\n' "$TOKEN" >> "$STATE_DIR/.env"
fi
chmod 600 "$STATE_DIR/.env"
echo "    저장 완료 (권한 600): $STATE_DIR/.env"

echo "==> 4/4  텔레그램 API 연결 확인"
BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT
HTTP_CODE=$(curl -s --max-time 15 -o "$BODY_FILE" -w '%{http_code}' \
  "https://api.telegram.org/bot${TOKEN}/getMe" 2>/dev/null) || CURL_RC=$?
CURL_RC=${CURL_RC:-0}

case "$HTTP_CODE" in
  200)
    BOT_NAME=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["result"]["username"] if d.get("ok") else "")' "$BODY_FILE" 2>/dev/null || true)
    if [ -n "$BOT_NAME" ]; then
      echo "    OK — 봇 확인됨: @${BOT_NAME}  (t.me/${BOT_NAME})"
    else
      echo "    경고: 200 응답이지만 봇 정보를 읽지 못했습니다. 응답:" >&2
      head -c 200 "$BODY_FILE" >&2; echo >&2
    fi
    ;;
  401)
    echo "    실패: 토큰이 유효하지 않습니다 (401 Unauthorized)." >&2
    echo "           → @BotFather 에서 /token 으로 재확인하거나 /revoke 로 새로 발급하세요." >&2
    echo "           네트워크는 정상입니다 — 텔레그램까지 도달했고 거부당한 것입니다." >&2
    exit 1
    ;;
  404)
    echo "    실패: 봇을 찾을 수 없습니다 (404). 토큰 형식은 맞지만 해당 봇이 없습니다." >&2
    echo "           → 삭제된 봇이거나 토큰을 잘못 복사했을 수 있습니다." >&2
    exit 1
    ;;
  000|"")
    echo "    실패: api.telegram.org 에 연결하지 못했습니다 (curl exit ${CURL_RC})." >&2
    echo "           토큰 문제가 아니라 네트워크/이그레스 정책 문제입니다." >&2
    if [ -n "${HTTPS_PROXY:-}" ]; then
      echo "           프록시 사용 중: ${HTTPS_PROXY}" >&2
      echo "           프록시가 기록한 차단 사유 확인:" >&2
      echo "             curl -sS \"\$HTTPS_PROXY/__agentproxy/status\"" >&2
      echo "           403(정책 거부)이면 환경의 Network access 를 Custom 으로 바꾸고" >&2
      echo "           Allowed domains 에 api.telegram.org 를 추가한 뒤 새 세션에서 실행하세요." >&2
    else
      echo "           방화벽/DNS/VPN 이 api.telegram.org 를 막고 있는지 확인하세요." >&2
    fi
    exit 1
    ;;
  *)
    echo "    실패: 예기치 못한 응답 (HTTP ${HTTP_CODE}). 응답 본문:" >&2
    head -c 200 "$BODY_FILE" >&2; echo >&2
    exit 1
    ;;
esac

cat <<EOF

────────────────────────────────────────────────────────
설정 완료. 이제 아래 순서로 페어링하세요.

1) 채널 플래그를 붙여 새 세션 시작 (이 플래그 없으면 서버가 연결되지 않습니다):

     claude --channels plugin:telegram@claude-plugins-official

2) 그 세션을 켜 둔 채로, 텔레그램에서 봇에게 DM 을 보냅니다.
   봇이 6자리 페어링 코드로 응답합니다.

3) 세션 안에서 코드를 승인:

     /telegram:access pair <코드>

4) 페어링이 끝나면 반드시 잠그세요 (모르는 사람이 코드를 못 받게):

     /telegram:access policy allowlist

상태 확인은 인자 없이:  /telegram:configure
────────────────────────────────────────────────────────
EOF
