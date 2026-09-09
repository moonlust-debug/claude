#!/usr/bin/env bash
# 새 머신 부트스트랩 — 이 저장소가 들고 다니는 Claude Code 환경을 한 번에 깐다.
#
# 사용법:
#   ./setup.sh [옵션]
#   curl -fsSL https://raw.githubusercontent.com/moonlust-debug/claude/main/setup.sh | bash
#
# 옵션:
#   --dir <경로>       저장소를 둘 위치 (클론이 필요할 때만 쓰임, 기본 $HOME/claude)
#   --skip-claude      Claude Code 설치 단계를 건너뛴다
#   --skip-link        ~/.claude/skills 링크 단계를 건너뛴다
#   --skip-settings    사용자 설정 병합 단계를 건너뛴다
#   --skip-skills      개인·원격 스킬 설치 단계를 건너뛴다
#
# 하는 일:
#   1. Claude Code 확보 (없으면 공식 네이티브 인스톨러)
#   2. 이 저장소 확보 (curl 로 실행돼 사본이 없으면 클론)
#   3. ~/.claude/skills → <저장소>/skills 링크. Windows 는 정션.
#   4. ~/.claude/settings.json 에 사용자 전역 키 병합
#   5. .claude/hooks/install-skills.sh 재사용해 스킬 설치
#
# 모든 단계는 멱등하다. 이미 되어 있으면 건너뛴다. 한 단계가 실패해도 나머지는
# 계속 진행하고 마지막에 한 번에 보고한다 — 부트스트랩이 중간에 끊기면 어디까지
# 됐는지 사람이 되짚어야 하기 때문이다.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/claude-setup.log"
REMOTE="https://github.com/moonlust-debug/claude.git"
CLONE_DIR="$HOME/claude"
SKIP_CLAUDE=0
SKIP_LINK=0
SKIP_SETTINGS=0
SKIP_SKILLS=0

done_steps=()
skipped=()
failed=()
notes=()

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          [ $# -ge 2 ] || { echo "오류: --dir 에 경로가 없습니다." >&2; exit 1; }
                    CLONE_DIR="$2"; shift 2 ;;
    --dir=*)        CLONE_DIR="${1#--dir=}"; shift ;;
    --skip-claude)  SKIP_CLAUDE=1; shift ;;
    --skip-link)    SKIP_LINK=1; shift ;;
    --skip-settings) SKIP_SETTINGS=1; shift ;;
    --skip-skills)  SKIP_SKILLS=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "오류: 알 수 없는 옵션 $1" >&2; usage >&2; exit 1 ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# 두 경로가 결국 같은 곳을 가리키는지. 심링크든 Windows 정션이든 cd 뒤 `pwd -P`
# 는 실체 경로를 내놓으므로, 링크 종류를 판별하지 않고도 확인된다.
same_path() {
  local a b
  a="$(cd "$1" 2>/dev/null && pwd -P)" || return 1
  b="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
  [ "$a" = "$b" ]
}

is_windows() { case "${OSTYPE:-}" in msys*|cygwin*) return 0 ;; *) return 1 ;; esac; }

echo "claude setup: 로그는 $LOG"
: >"$LOG"

# ── 1. Claude Code ────────────────────────────────────────────────────────────
if [ "$SKIP_CLAUDE" -eq 1 ]; then
  skipped+=("claude(요청)")
elif have claude; then
  skipped+=("claude($(claude --version 2>/dev/null | head -1))")
else
  echo "claude setup: Claude Code 설치 중…"
  if is_windows; then
    # Git Bash 에서 install.sh 를 돌리면 ~/.local/bin 에 유닉스용 런처가 깔린다.
    # 네이티브 Windows 는 PowerShell 인스톨러가 정답이므로 안내만 한다.
    failed+=("claude")
    notes+=("Windows 는 PowerShell 에서: irm https://claude.ai/install.ps1 | iex")
  elif have curl && curl -fsSL https://claude.ai/install.sh | bash >>"$LOG" 2>&1; then
    # 인스톨러는 ~/.local/bin 에 깔지만 현재 셸의 PATH 에는 아직 없을 수 있다.
    export PATH="$HOME/.local/bin:$PATH"
    if have claude; then
      done_steps+=("claude")
      notes+=("PATH 에 \$HOME/.local/bin 이 없으면 셸 프로필에 추가하세요.")
    else
      failed+=("claude")
    fi
  else
    failed+=("claude")
    notes+=("설치 실패. https://code.claude.com/docs/en/setup 의 대체 방법을 보세요.")
  fi
fi

# ── 2. 저장소 ─────────────────────────────────────────────────────────────────
# curl | bash 로 실행되면 BASH_SOURCE 가 실제 파일이 아니다. 그때만 클론한다.
REPO_DIR=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  candidate="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -d "$candidate/skills" ] && REPO_DIR="$candidate"
fi

if [ -n "$REPO_DIR" ]; then
  skipped+=("repo($REPO_DIR)")
elif [ -d "$CLONE_DIR/.git" ]; then
  REPO_DIR="$CLONE_DIR"
  skipped+=("repo($REPO_DIR)")
elif have git && git clone "$REMOTE" "$CLONE_DIR" >>"$LOG" 2>&1; then
  REPO_DIR="$CLONE_DIR"
  done_steps+=("repo($REPO_DIR)")
else
  failed+=("repo")
  notes+=("클론 실패: git clone $REMOTE $CLONE_DIR")
fi

# ── 3. ~/.claude/skills 링크 ──────────────────────────────────────────────────
# Claude Code 에는 개인 스킬 경로를 옮기는 설정 키가 없다. 그래서 저장소의
# skills/ 를 실체로 두고 ~/.claude/skills 가 그리로 향하게 한다. 이러면 이후
# `npx skills add --global` 이 설치하는 것까지 전부 저장소 안에 떨어진다.
SKILLS_LINK="$HOME/.claude/skills"
if [ "$SKIP_LINK" -eq 1 ]; then
  skipped+=("skills-link(요청)")
elif [ -z "$REPO_DIR" ]; then
  failed+=("skills-link")
elif same_path "$SKILLS_LINK" "$REPO_DIR/skills"; then
  skipped+=("skills-link")
elif [ -e "$SKILLS_LINK" ] && ! rmdir "$SKILLS_LINK" 2>/dev/null; then
  # 내용이 있는 진짜 디렉터리다. 남의 스킬이 들어 있을 수 있으니 지우지 않는다.
  # 링크는 포기하고 5단계의 복사 경로에 맡긴다 — 동작은 하되 한 방향이다.
  skipped+=("skills-link(기존 디렉터리 유지)")
  notes+=("$SKILLS_LINK 가 이미 실체 디렉터리입니다. 링크를 원하면 다른 곳으로 옮긴 뒤 재실행하세요.")
else
  mkdir -p "$HOME/.claude"
  if is_windows; then
    cmd //c mklink /J "$(cygpath -w "$SKILLS_LINK")" "$(cygpath -w "$REPO_DIR/skills")" >>"$LOG" 2>&1
  else
    ln -s "$REPO_DIR/skills" "$SKILLS_LINK" >>"$LOG" 2>&1
  fi
  if same_path "$SKILLS_LINK" "$REPO_DIR/skills"; then
    done_steps+=("skills-link")
  else
    failed+=("skills-link")
  fi
fi

# ── 4. 사용자 설정 병합 ───────────────────────────────────────────────────────
# 이 저장소의 프로젝트 설정은 여기서 `claude` 를 띄울 때만 유효하다.
# 모든 디렉터리에 걸려야 하는 키만 사용자 설정으로 올린다.
#
# remoteControlAtStartup=false: 켜져 있으면 `claude` 를 띄울 때마다
# <호스트명>-<단어>-<단어> 이름의 Remote Control 세션이 claude.ai 목록에 쌓인다.
USER_SETTINGS="$HOME/.claude/settings.json"
USER_KEYS='{"remoteControlAtStartup": false}'
if [ "$SKIP_SETTINGS" -eq 1 ]; then
  skipped+=("settings(요청)")
elif ! have node; then
  skipped+=("settings(node 없음)")
  notes+=("$USER_SETTINGS 에 \"remoteControlAtStartup\": false 를 직접 넣으세요.")
else
  # 파일 통째 교체는 금물이다 — 훅·플러그인 설정이 조용히 사라진다.
  # 이미 있는 키는 사용자가 일부러 넣은 값으로 보고 건드리지 않는다.
  node -e '
    const fs = require("fs"), path = require("path");
    const p = process.argv[1];
    let cur = {};
    if (fs.existsSync(p)) {
      const raw = fs.readFileSync(p, "utf8").trim();
      if (raw) { try { cur = JSON.parse(raw); } catch (e) { process.exit(2); } }
    }
    let changed = false;
    for (const [k, v] of Object.entries(JSON.parse(process.argv[2]))) {
      if (!(k in cur)) { cur[k] = v; changed = true; }
    }
    if (!changed) process.exit(3);
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, JSON.stringify(cur, null, 2) + "\n");
  ' "$USER_SETTINGS" "$USER_KEYS" >>"$LOG" 2>&1
  case $? in
    0) done_steps+=("settings") ;;
    3) skipped+=("settings") ;;
    2) failed+=("settings")
       notes+=("$USER_SETTINGS 가 유효한 JSON 이 아닙니다. 고친 뒤 재실행하세요.") ;;
    *) failed+=("settings") ;;
  esac
fi

# ── 5. 스킬 ───────────────────────────────────────────────────────────────────
# SessionStart 훅과 같은 스크립트를 그대로 부른다. 설치 목록이 두 군데로
# 갈라지지 않게 하려는 것이다.
HOOK="$REPO_DIR/.claude/hooks/install-skills.sh"
if [ "$SKIP_SKILLS" -eq 1 ]; then
  skipped+=("skills(요청)")
elif [ -z "$REPO_DIR" ] || [ ! -f "$HOOK" ]; then
  failed+=("skills")
elif CLAUDE_PROJECT_DIR="$REPO_DIR" bash "$HOOK"; then
  # 훅은 실제로 설치한 스킬만 자기 손으로 한 줄 보고한다.
  done_steps+=("skills(훅 실행)")
else
  failed+=("skills")
fi

# ── 보고 ──────────────────────────────────────────────────────────────────────
echo
[ ${#done_steps[@]} -gt 0 ] && echo "완료:     ${done_steps[*]}"
[ ${#skipped[@]}    -gt 0 ] && echo "건너뜀:   ${skipped[*]}"
[ ${#failed[@]}     -gt 0 ] && echo "실패:     ${failed[*]}  (자세한 내용은 $LOG)"
for note in ${notes[@]+"${notes[@]}"}; do echo "  - $note"; done

if [ ${#failed[@]} -eq 0 ]; then
  echo
  echo "다음 단계:"
  echo "  claude          로그인하고 세션 시작"
  echo "  claude doctor   설치 상태 점검"
  echo "  $REPO_DIR/telegram/setup.sh <BOT_TOKEN>   텔레그램 채널이 필요하면"
fi

# 부분 실패도 종료 코드로 알린다. 부트스트랩은 사람이 보고 있는 스크립트다.
[ ${#failed[@]} -eq 0 ]
