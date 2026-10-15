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
#   --skip-headroom    Headroom CLI 설치 단계를 건너뛴다
#   --skip-settings    사용자 설정 병합 단계를 건너뛴다
#   --skip-skills      개인·원격 스킬 설치 단계를 건너뛴다
#   --skip-omniroute   OmniRoute 설치 단계를 건너뛴다
#
# 하는 일:
#   1. Claude Code 확보 (없으면 공식 네이티브 인스톨러)
#   2. 이 저장소 확보 (curl 로 실행돼 사본이 없으면 클론)
#   3. ~/.claude/skills → <저장소>/skills 링크. Windows 는 정션.
#   4. Headroom CLI 확보 (uv 또는 pip)
#   5. ~/.claude/settings.json 에 사용자 전역 키 병합
#      (claude-mem 플러그인, headroom 플러그인 — CLI 가 잡힐 때만)
#   6. .claude/hooks/install-skills.sh 재사용해 스킬 설치
#   7. OmniRoute 게이트웨이 설치 (설치만 — 트래픽은 돌리지 않는다)
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
SKIP_HEADROOM=0
SKIP_OMNIROUTE=0

done_steps=()
skipped=()
failed=()
notes=()

# 머리말 주석이 그대로 도움말이다. 줄 번호를 박아 두면 주석을 고칠 때마다
# 어긋나므로 셰뱅 다음의 연속된 주석 블록을 끝까지 읽는다. curl | bash 로
# 실행되면 읽을 파일이 없으므로 그때는 한 줄 요약으로 대신한다.
usage() {
  if [ -r "${BASH_SOURCE[0]:-}" ]; then
    awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "${BASH_SOURCE[0]}"
  else
    echo "사용법: setup.sh [--dir <경로>] [--skip-claude] [--skip-link] [--skip-headroom] [--skip-settings] [--skip-skills] [--skip-omniroute]"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          [ $# -ge 2 ] || { echo "오류: --dir 에 경로가 없습니다." >&2; exit 1; }
                    CLONE_DIR="$2"; shift 2 ;;
    --dir=*)        CLONE_DIR="${1#--dir=}"; shift ;;
    --skip-claude)  SKIP_CLAUDE=1; shift ;;
    --skip-link)    SKIP_LINK=1; shift ;;
    --skip-settings) SKIP_SETTINGS=1; shift ;;
    --skip-skills)  SKIP_SKILLS=1; shift ;;
    --skip-headroom) SKIP_HEADROOM=1; shift ;;
    --skip-omniroute) SKIP_OMNIROUTE=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              echo "오류: 알 수 없는 옵션 $1" >&2; usage >&2; exit 1 ;;
  esac
done

# curl | bash 로 실행되면 이 스크립트의 본문 자체가 stdin 이다. 자식 프로세스가
# stdin 을 읽어 버리면(예: npx 는 실제로 읽는다) 남은 본문이 통째로 사라져 스크립트가
# 조용히 중간에 끝난다. 그래서 아래 모든 외부 명령에 </dev/null 을 붙인다.
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
  elif have curl && curl -fsSL https://claude.ai/install.sh </dev/null | bash >>"$LOG" 2>&1; then
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
elif have git && git clone "$REMOTE" "$CLONE_DIR" </dev/null >>"$LOG" 2>&1; then
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
    cmd //c mklink /J "$(cygpath -w "$SKILLS_LINK")" "$(cygpath -w "$REPO_DIR/skills")" </dev/null >>"$LOG" 2>&1
  else
    ln -s "$REPO_DIR/skills" "$SKILLS_LINK" </dev/null >>"$LOG" 2>&1
  fi
  if same_path "$SKILLS_LINK" "$REPO_DIR/skills"; then
    done_steps+=("skills-link")
  else
    failed+=("skills-link")
  fi
fi

# ── 4. Headroom CLI ───────────────────────────────────────────────────────────
# Headroom 은 스킬이 아니다 — 저장소에 SKILL.md 가 하나도 없다. 실체는 파이썬
# CLI(`headroom-ai`)와 그것을 부르는 플러그인 훅이다. 그래서 CLI 를 먼저 깔고,
# 다음 단계에서 CLI 가 실제로 잡힐 때만 플러그인을 켠다 — 훅이 SessionStart 와
# 모든 Bash 호출마다 `headroom` 을 부르기 때문에, CLI 없이 플러그인만 켜면
# 매 도구 호출이 실패한 훅을 달고 다닌다.
#
# extras 는 [proxy,code] 로 간다. README 가 [proxy] 를 "most common install" 로
# 부르고, [code] 가 간판 기능인 tree-sitter AST 압축이다. [all] 은 [ml] 을 통해
# torch 를 끌어와 수 GB 가 되므로 부트스트랩에는 맞지 않는다. 필요하면 나중에
# uv tool install --python 3.13 "headroom-ai[all]" 로 덮어쓰면 된다.
if [ "$SKIP_HEADROOM" -eq 1 ]; then
  skipped+=("headroom(요청)")
elif have headroom; then
  skipped+=("headroom")
else
  if have uv; then
    uv tool install --python 3.13 "headroom-ai[proxy,code]" </dev/null >>"$LOG" 2>&1
  elif have pip3; then
    pip3 install --user "headroom-ai[proxy,code]" </dev/null >>"$LOG" 2>&1
  elif have pip; then
    pip install --user "headroom-ai[proxy,code]" </dev/null >>"$LOG" 2>&1
  fi
  # uv tool install 도 pip --user 도 ~/.local/bin 에 떨어뜨린다. 지금 셸의 PATH
  # 에는 없을 수 있으므로 붙여 두고 다시 확인한다.
  export PATH="$HOME/.local/bin:$PATH"
  if have headroom; then
    done_steps+=("headroom")
    notes+=("headroom 은 CLI·플러그인만 깔았습니다. 압축을 켜려면: headroom deploy (또는 headroom wrap claude), 확인은 headroom doctor")
  else
    failed+=("headroom")
    notes+=("headroom 설치 실패. uv 나 pip3 가 있는지 보고 직접: uv tool install --python 3.13 \"headroom-ai[proxy,code]\"")
  fi
fi

# ── 5. 사용자 설정 병합 ───────────────────────────────────────────────────────
# 이 저장소의 프로젝트 설정은 여기서 `claude` 를 띄울 때만 유효하다.
# 모든 디렉터리에 걸려야 하는 키만 사용자 설정으로 올린다.
#
# remoteControlAtStartup=false: 켜져 있으면 `claude` 를 띄울 때마다
# <호스트명>-<단어>-<단어> 이름의 Remote Control 세션이 claude.ai 목록에 쌓인다.
#
# claude-mem: 세션 간 기억을 쌓는 플러그인. 스킬 파일만으로는 동작하지 않고
# 훅·워커·SQLite 가 필요해서 플러그인으로 넣는다. 이 저장소의 프로젝트 설정이
# 아니라 사용자 설정에 넣는 이유는, 기억이 이 디렉터리에서만 쌓이면 쓸모가
# 없기 때문이다.
USER_SETTINGS="$HOME/.claude/settings.json"
USER_KEYS='{
  "remoteControlAtStartup": false,
  "extraKnownMarketplaces": {
    "thedotmack": { "source": { "source": "github", "repo": "thedotmack/claude-mem" } }
  },
  "enabledPlugins": { "claude-mem@thedotmack": true }
}'

# headroom 플러그인은 CLI 가 실제로 잡힐 때만 켠다. 훅이 SessionStart 와 모든
# Bash·PowerShell 호출마다 `headroom init hook ensure` 를 부르므로, CLI 가 없으면
# 세션 내내 실패하는 훅이 붙는다. 그래서 앞 단계가 성공했을 때만 등록한다.
HEADROOM_KEYS='{}'
if have headroom; then
  HEADROOM_KEYS='{
    "extraKnownMarketplaces": {
      "headroom-marketplace": { "source": { "source": "github", "repo": "headroomlabs-ai/headroom" } }
    },
    "enabledPlugins": { "headroom@headroom-marketplace": true }
  }'
fi

if [ "$SKIP_SETTINGS" -eq 1 ]; then
  skipped+=("settings(요청)")
elif ! have node; then
  skipped+=("settings(node 없음)")
  notes+=("$USER_SETTINGS 에 \"remoteControlAtStartup\": false 를 직접 넣으세요.")
else
  # 파일 통째 교체는 금물이다 — 훅·플러그인 설정이 조용히 사라진다.
  # 이미 있는 키는 사용자가 일부러 넣은 값으로 보고 건드리지 않는다.
  # 객체 키(extraKnownMarketplaces·enabledPlugins)는 한 겹 더 들어가 하위 키만
  # 채운다. 통째로 건너뛰면 마켓플레이스가 하나라도 있는 순간 우리 항목이
  # 영영 안 들어가고, 통째로 덮으면 남의 마켓플레이스가 사라진다.
  node -e '
    const fs = require("fs"), path = require("path");
    const p = process.argv[1];
    const isPlain = (v) => v !== null && typeof v === "object" && !Array.isArray(v);

    // 없는 키만 채운다. 값이 양쪽 다 객체면 그 안으로 내려가 같은 규칙을 쓴다.
    function fill(cur, want) {
      let changed = false;
      for (const [k, v] of Object.entries(want)) {
        if (!(k in cur)) { cur[k] = v; changed = true; }
        else if (isPlain(v) && isPlain(cur[k]) && fill(cur[k], v)) { changed = true; }
      }
      return changed;
    }

    let cur = {};
    if (fs.existsSync(p)) {
      const raw = fs.readFileSync(p, "utf8").trim();
      if (raw) { try { cur = JSON.parse(raw); } catch (e) { process.exit(2); } }
    }
    // argv[2..] 는 병합할 JSON 덩어리들. 조건부로 켜지는 것(headroom)이 있어서
    // 하나로 합쳐 넘기지 않고 여러 개를 받는다.
    let changed = false;
    for (const blob of process.argv.slice(2)) {
      if (fill(cur, JSON.parse(blob))) changed = true;
    }
    if (!changed) process.exit(3);
    fs.mkdirSync(path.dirname(p), { recursive: true });
    fs.writeFileSync(p, JSON.stringify(cur, null, 2) + "\n");
  ' "$USER_SETTINGS" "$USER_KEYS" "$HEADROOM_KEYS" </dev/null >>"$LOG" 2>&1
  case $? in
    0) done_steps+=("settings") ;;
    3) skipped+=("settings") ;;
    2) failed+=("settings")
       notes+=("$USER_SETTINGS 가 유효한 JSON 이 아닙니다. 고친 뒤 재실행하세요.") ;;
    *) failed+=("settings") ;;
  esac
fi

# ── 6. 스킬 ───────────────────────────────────────────────────────────────────
# SessionStart 훅과 같은 스크립트를 그대로 부른다. 설치 목록이 두 군데로
# 갈라지지 않게 하려는 것이다.
HOOK="$REPO_DIR/.claude/hooks/install-skills.sh"
if [ "$SKIP_SKILLS" -eq 1 ]; then
  skipped+=("skills(요청)")
elif [ -z "$REPO_DIR" ] || [ ! -f "$HOOK" ]; then
  failed+=("skills")
elif CLAUDE_PROJECT_DIR="$REPO_DIR" bash "$HOOK" </dev/null; then
  # 훅은 실제로 설치한 스킬만 자기 손으로 한 줄 보고한다.
  done_steps+=("skills(훅 실행)")
else
  failed+=("skills")
fi

# ── 7. OmniRoute ──────────────────────────────────────────────────────────────
# 로컬 AI 게이트웨이(localhost:20128). 설치만 하고 Claude Code 를 그리로 붙이지는
# 않는다 — ANTHROPIC_BASE_URL 을 전역으로 돌리면 평소 쓰는 계정의 트래픽까지 전부
# 제3자 프로바이더로 새기 때문이다. 라우팅은 필요할 때 그 셸에서만 켠다.
#
# 주의: 이 패키지는 해명되지 않은 보안 지적을 안고 있다. Socket.dev 가
# omniroute@3.8.5 를 공급망 점수 48 / "AI-detected potential malware" 로 표시했고
# (루트 CA 설치·DNS 조작·MITM 서버·키체인 자격증명 수집 주장), 해당 이슈
# github.com/diegosouzapw/OmniRoute/issues/2863 는 메인테이너 응답 없이 열려 있다.
# CVE-2026-49352 도 이 프로젝트에 할당돼 있다. 위험을 알고 넣은 단계다.
# 빼려면 --skip-omniroute, 이미 깔았으면 npm uninstall -g omniroute.
if [ "$SKIP_OMNIROUTE" -eq 1 ]; then
  skipped+=("omniroute(요청)")
elif have omniroute; then
  skipped+=("omniroute")
elif ! have npm; then
  failed+=("omniroute")
  notes+=("npm 이 없어 omniroute 를 설치하지 못했습니다.")
elif npm install -g omniroute </dev/null >>"$LOG" 2>&1 && have omniroute; then
  done_steps+=("omniroute")
else
  failed+=("omniroute")
fi

if have omniroute; then
  notes+=("omniroute 는 설치만 됐습니다. 쓸 때만: 한 셸에서 omniroute, 다른 셸에서 ANTHROPIC_BASE_URL=http://localhost:20128/v1 claude")
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
