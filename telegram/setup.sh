#!/usr/bin/env bash
# Telegram 채널 로컬 설정 — 본인 머신에서 실행하세요.
#
# 사용법:
#   ./setup.sh <BOT_TOKEN> [--allow <ID>[,<ID>...]] [--no-web-tools]
#
# 토큰은 텔레그램에서 @BotFather 에게 /newbot 을 보내 발급받습니다.
# (형식: 123456789:AAH... — 숫자 접두사 + 콜론 + 문자열)
#
# --allow 를 주면 해당 숫자 사용자 ID 를 허용 목록에 넣고 정책을 allowlist 로
# 잠근 채로 시작합니다. 페어링 코드를 주고받는 단계가 사라집니다.
# 페어링은 숫자 ID 를 알아내기 위한 절차일 뿐이므로, ID 를 이미 안다면 불필요합니다.
# 본인 ID 는 텔레그램에서 @userinfobot 에게 물어보면 알려줍니다.
#
# --allow 없이 실행하면 access.json 을 건드리지 않습니다. 파일이 없으면
# 플러그인 기본값(pairing 정책)이 적용되어 첫 DM 에 페어링 코드가 발급됩니다.
#
# 기본적으로 웹 도구(WebSearch/WebFetch)를 사용자 설정에 허용해 둡니다. 채널
# 세션은 권한 프롬프트를 텔레그램으로 띄울 수단이 없어서, 미리 허용해 두지
# 않으면 검색이 필요한 요청이 "권한 없음"으로 끝납니다. --no-web-tools 를 주면
# 이 단계를 건너뜁니다.

set -euo pipefail

TOKEN=""
ALLOW_IDS=""
WEB_TOOLS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --allow)
      [ $# -ge 2 ] || { echo "오류: --allow 에 ID 가 없습니다." >&2; exit 1; }
      ALLOW_IDS="$2"; shift 2 ;;
    --allow=*)
      ALLOW_IDS="${1#--allow=}"; shift ;;
    --no-web-tools)
      WEB_TOOLS=0; shift ;;
    -h|--help)
      sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)
      echo "오류: 알 수 없는 옵션 $1" >&2; exit 1 ;;
    *)
      [ -z "$TOKEN" ] || { echo "오류: 토큰이 두 번 지정됐습니다." >&2; exit 1; }
      TOKEN="$1"; shift ;;
  esac
done

if [ -z "$TOKEN" ]; then
  echo "오류: 봇 토큰을 인자로 넘겨주세요." >&2
  echo "사용법: $0 <BOT_TOKEN> [--allow <ID>[,<ID>...]]" >&2
  exit 1
fi

if ! printf '%s' "$TOKEN" | grep -qE '^[0-9]+:[A-Za-z0-9_-]+$'; then
  echo "오류: 토큰 형식이 BotFather 토큰과 다릅니다 (예: 123456789:AAH...)." >&2
  exit 1
fi

if [ -n "$ALLOW_IDS" ] && ! printf '%s' "$ALLOW_IDS" | grep -qE '^[0-9]+(,[0-9]+)*$'; then
  echo "오류: --allow 는 쉼표로 구분된 숫자 ID 여야 합니다 (예: 5046959738)." >&2
  echo "       @username 이 아니라 숫자 ID 입니다. @userinfobot 에서 확인하세요." >&2
  exit 1
fi

CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
STATE_DIR="${TELEGRAM_STATE_DIR:-$CONFIG_DIR/channels/telegram}"
SETTINGS_FILE="$CONFIG_DIR/settings.json"

echo "==> 1/5  전제 조건 확인"
command -v claude >/dev/null || { echo "claude CLI 가 없습니다. https://claude.com/claude-code 참고" >&2; exit 1; }
if ! command -v bun >/dev/null; then
  echo "bun 이 없습니다. MCP 서버가 bun 위에서 동작합니다. 설치:" >&2
  echo "  curl -fsSL https://bun.sh/install | bash" >&2
  exit 1
fi
echo "    claude: $(claude --version)"
echo "    bun:    $(bun --version)"

echo "==> 2/5  마켓플레이스 + 플러그인 설치"
claude plugin marketplace add anthropics/claude-plugins-official || true
claude plugin install telegram@claude-plugins-official || true
claude plugin list | sed -n '1,12p'

echo "==> 3/5  토큰 저장 → $STATE_DIR/.env"
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

if [ -n "$ALLOW_IDS" ]; then
  # 허용 목록을 직접 써서 페어링 단계를 건너뛴다.
  # access.json 은 인바운드 메시지마다 다시 읽히므로 재시작이 필요 없다.
  ACCESS_FILE="$STATE_DIR/access.json"
  [ -f "$ACCESS_FILE" ] && cp "$ACCESS_FILE" "$ACCESS_FILE.bak" && echo "    기존 access.json → access.json.bak 백업"
  JSON_IDS=$(printf '%s' "$ALLOW_IDS" | sed 's/,/", "/g')
  cat > "$ACCESS_FILE" <<EOF
{
  "dmPolicy": "allowlist",
  "allowFrom": ["$JSON_IDS"],
  "groups": {},
  "ackReaction": "👀",
  "replyToMode": "first"
}
EOF
  echo "    접근 정책: allowlist / 허용 ID: $ALLOW_IDS"
  echo "    → 페어링 코드 없이 바로 통합니다 (코드는 발급되지 않는 것이 정상)."
fi

echo "==> 4/5  웹 도구 권한 → $SETTINGS_FILE"
# 채널 세션은 권한 프롬프트를 텔레그램으로 띄울 수단이 없다. 미리 허용해 두지
# 않으면 검색이 필요한 요청이 그대로 "권한 없음"으로 끝난다.
#
# 프로젝트 설정(.claude/settings.json)이 아니라 사용자 설정에 쓰는 이유는,
# 프로젝트 설정이 세션을 띄운 디렉터리에서만 유효하기 때문이다. 채널 세션을
# 어디서 띄우든 통하게 하려면 사용자 레벨이어야 한다.
#
# WebFetch 를 같이 넣는 것은 검색 결과 페이지를 열어 읽는 두 번째 단계에서
# 다시 막히지 않게 하기 위해서다.
if [ "$WEB_TOOLS" = 0 ]; then
  echo "    건너뜀 (--no-web-tools)"
elif ! command -v python3 >/dev/null; then
  echo "    건너뜀: python3 가 없어 JSON 을 병합하지 못했습니다." >&2
  echo "           $SETTINGS_FILE 의 permissions.allow 에 다음을 직접 넣으세요:" >&2
  echo '             "WebSearch", "WebFetch"' >&2
else
  mkdir -p "$CONFIG_DIR"
  # 기존 설정은 보존하고 없는 항목만 덧붙인다. 추가한 항목을 stdout 으로 돌려준다.
  if ADDED=$(python3 - "$SETTINGS_FILE" <<'PY'
import json, os, shutil, sys

path = sys.argv[1]
want = ["WebSearch", "WebFetch"]

# 새로 만드는 경우에만 $schema 를 맨 앞에 둔다 (기존 파일의 키 순서는 건드리지 않음)
existed = os.path.exists(path)
data = {} if existed else {"$schema": "https://json.schemastore.org/claude-code-settings.json"}
if existed:
    with open(path, encoding="utf-8") as f:
        text = f.read().strip()
    if text:
        try:
            data = json.loads(text)
        except json.JSONDecodeError as e:
            # 깨진 파일을 덮어쓰지 않는다 — 셸이 경고하고 수동 안내로 넘어간다
            raise SystemExit(f"    {os.path.basename(path)} JSON 파싱 실패: {e}")
if not isinstance(data, dict):
    raise SystemExit("    settings.json 최상위가 객체가 아닙니다")

# 값을 만들기 전에 형태부터 확인한다 — 예상 밖의 타입이면 건드리지 않고 빠진다
perms = data.setdefault("permissions", {})
if not isinstance(perms, dict):
    raise SystemExit("    permissions 가 객체가 아닙니다")
allow = perms.setdefault("allow", [])
if not isinstance(allow, list):
    raise SystemExit("    permissions.allow 가 배열이 아닙니다")

added = [t for t in want if t not in allow]
if added:
    allow.extend(added)
    if existed:
        shutil.copy2(path, path + ".bak")
        print("    기존 설정 → settings.json.bak 백업", file=sys.stderr)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp, path)  # 원자적 교체 — 중간 상태의 설정 파일이 읽히지 않게

print(" ".join(added))
PY
  ); then
    if [ -n "$ADDED" ]; then
      echo "    허용 추가: $ADDED"
    else
      echo "    이미 허용돼 있음 — 변경 없음"
    fi
  else
    echo "    경고: $SETTINGS_FILE 를 수정하지 못했습니다 (JSON 파싱 실패 등)." >&2
    echo "           파일을 직접 열어 permissions.allow 에 다음을 넣으세요:" >&2
    echo '             "WebSearch", "WebFetch"' >&2
  fi
fi

echo "==> 5/5  텔레그램 API 연결 확인"
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

if [ -n "$ALLOW_IDS" ]; then
  cat <<EOF

────────────────────────────────────────────────────────
설정 완료. 페어링 단계는 필요 없습니다.

채널 플래그를 붙여 세션을 시작하세요 (이 플래그 없으면 서버가 연결되지 않습니다):

     claude --channels plugin:telegram@claude-plugins-official

이미 떠 있는 세션이 있다면 재시작하세요 — 권한 설정은 세션 시작 시 한 번만 읽습니다.

세션을 켜 둔 채로 봇에게 DM 하면 바로 통합니다.
허용 목록에 없는 사람의 DM 은 조용히 버려집니다(코드도 나가지 않음).

허용 목록 변경:  /telegram:access add <ID>  /  remove <ID>
상태 확인:       /telegram:configure
────────────────────────────────────────────────────────
EOF
else
  cat <<EOF

────────────────────────────────────────────────────────
설정 완료. 이제 아래 순서로 페어링하세요.

1) 채널 플래그를 붙여 새 세션 시작 (이 플래그 없으면 서버가 연결되지 않습니다):

     claude --channels plugin:telegram@claude-plugins-official

   (이미 떠 있는 세션이 있다면 재시작하세요 — 권한 설정은 시작 시 한 번만 읽힙니다.)

2) 그 세션을 켜 둔 채로, 텔레그램에서 봇에게 DM 을 보냅니다.
   봇이 6자리 페어링 코드로 응답합니다.

3) 세션 안에서 코드를 승인:

     /telegram:access pair <코드>

4) 페어링이 끝나면 반드시 잠그세요 (모르는 사람이 코드를 못 받게):

     /telegram:access policy allowlist

숫자 ID 를 이미 안다면 위 과정을 건너뛸 수 있습니다:
     $0 <토큰> --allow <ID>

상태 확인은 인자 없이:  /telegram:configure
────────────────────────────────────────────────────────
EOF
fi
