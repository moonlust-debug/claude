<!-- Generated: 2026-08-25 | Updated: 2026-08-25 -->

# claude

## Purpose
moonlust-debug 의 Claude Code 개인 설정 보관소다. 코드 프로젝트가 아니라, 여러 머신과
웹/원격 세션에 걸쳐 같은 환경을 재현하기 위한 **설치 스크립트·훅·개인 스킬·권한 설정**을
모아 둔 곳이다. 웹 세션은 매번 새 컨테이너로 뜨기 때문에, 여기 있는 것들은 대부분
"세션 시작 시 없으면 설치한다"는 형태를 띤다.

## Key Files
| File | Description |
|------|-------------|
| `setup.sh` | 새 머신 부트스트랩. Claude Code 설치 확인 → 저장소 확보 → `~/.claude/skills` 링크 → 사용자 설정 병합 → 스킬 설치 → OmniRoute 설치. 멱등하다 |
| `README.md` | 저장소 소개와 새 머신 설치 절차 |
| `.gitignore` | `memory/` 만 제외 — 개인 메모리를 GitHub 로 올리지 않으려는 목적 |

## Subdirectories
| Directory | Purpose |
|-----------|---------|
| `.claude/` | 이 저장소의 프로젝트 설정과 SessionStart 훅 (see `.claude/hooks/AGENTS.md`) |
| `telegram/` | 텔레그램 채널 플러그인 설치 스크립트와 프록시 우회 기록 (see `telegram/AGENTS.md`) |
| `skills/` | 개인 스킬 실체. `~/.claude/skills` 가 정션으로 여기를 가리킨다 (see `skills/AGENTS.md`) |
| `memory/` | 세션 간 기억. `.gitignore` 로 추적 제외 — 문서화 대상 아님 |
| `.omc/` | oh-my-claudecode 가 만드는 세션 상태. 자동 생성물이라 문서화 대상 아님 |

## For AI Agents

### Working In This Directory
- `.claude/settings.json` 은 **파일 단위로 덮어쓰지 말 것.** 권한 목록과
  `hooks`/`extraKnownMarketplaces`/`enabledPlugins` 가 서로 다른 시기에 들어와서,
  통째로 교체하면 훅과 플러그인 설정이 조용히 사라진다. 반드시 키 단위로 병합한다.
- `memory/` 는 gitignore 대상이다. 여기 있는 파일을 커밋하려 하지 말 것.
- `remoteControlAtStartup: false` 는 지우지 말 것. 자동 접속이 켜져 있으면 `claude` 를
  띄울 때마다 `<호스트명>-<단어>-<단어>`(이 머신에서는 `pc-noble-haven` 처럼) 이름의
  Remote Control 세션이 claude.ai 세션 목록에 쌓인다. 대부분 곧 `computer_unreachable`
  로 죽어서 목록만 어지럽힌다. **프로젝트 설정의 `false` 는 이 저장소에서만 유효하다.**
  모든 디렉터리에서 막으려면 사용자 설정(`~/.claude/settings.json`, Windows 는
  `%USERPROFILE%\.claude\settings.json`)에 같은 키를 넣거나 `/config` 의
  "Enable Remote Control for all sessions" 를 끈다. 기능 자체를 없애려면
  `disableRemoteControl: true` 를 쓴다.
- `setup.sh` 는 최초 1회용이 아니라 **아무 때나 다시 돌려도 되는 스크립트**다. 단계마다
  "이미 되어 있으면 건너뛴다" 를 지킨다. 5단계는 `.claude/hooks/install-skills.sh` 를
  그대로 호출한다 — 설치 목록이 두 군데로 갈라지지 않게 하려는 것이니, 새 스킬은
  훅 쪽에만 넣는다.
- `setup.sh` 가 사용자 설정(`~/.claude/settings.json`)에 넣는 키는 **없는 키만** 채운다.
  이미 있는 값은 사용자가 일부러 넣은 것으로 보고 건드리지 않는다. `extraKnownMarketplaces`
  와 `enabledPlugins` 는 한 겹 더 들어가 하위 키만 채운다 — 통째로 건너뛰면 마켓플레이스가
  하나라도 있는 순간 우리 항목이 영영 안 들어가고, 통째로 덮으면 남의 것이 사라진다.
- **Headroom 은 스킬이 아니다** — 저장소에 `SKILL.md` 가 하나도 없다(`npx skills add
  headroomlabs-ai/headroom --list` → "No skills found"). 레지스트리에 `headroom` 이라는
  이름으로 올라온 것들은 제3자 사본이니 공식으로 착각하지 말 것. 실체는 파이썬 CLI
  (`headroom-ai`)와 그것을 부르는 플러그인 훅이다. 그래서 4단계가 CLI 를 깔고,
  5단계는 **`have headroom` 일 때만** 플러그인을 켠다. 훅이 SessionStart 와 모든
  Bash·PowerShell 호출마다 `headroom init hook ensure` 를 부르므로, CLI 없이 플러그인만
  켜면 매 도구 호출에 실패하는 훅이 붙는다. 이 순서와 조건을 뒤집지 말 것.
- **claude-mem 은 스킬이 아니라 플러그인으로 넣었다.** 기억을 쌓는 실체는 훅·워커·SQLite
  라서 `npx skills add` 로 스킬 20개를 받아도 마크다운만 오고 조회할 것이 없다
  (`npm install -g claude-mem` 도 SDK 만 깔린다). 그래서 훅의 `SKILLS` 배열이 아니라
  `setup.sh` 4단계의 사용자 설정 병합으로 등록한다. 프로젝트 설정이 아니라 사용자 설정인
  이유는, 세션 간 기억이 이 디렉터리에서만 쌓이면 쓸모가 없기 때문이다.
- `setup.sh` 6단계의 **OmniRoute 는 해명되지 않은 보안 지적을 안은 채로 들어와 있다.**
  Socket.dev 가 `omniroute@3.8.5` 를 공급망 점수 48 / "AI-detected potential malware" 로
  표시했고(루트 CA 설치·DNS 조작·MITM 서버·키체인 자격증명 수집 주장),
  [issues/2863](https://github.com/diegosouzapw/OmniRoute/issues/2863) 은 메인테이너 응답
  없이 열려 있으며, CVE-2026-49352 가 이 프로젝트에 할당돼 있다. **사용자가 위험을 듣고
  선택한 단계다** — 지적을 몰라서 들어온 것이 아니니 조용히 빼지 말고, 반대로 "안전하다"고
  주석을 고쳐 쓰지도 말 것. 단계는 게이트웨이를 **설치만** 한다. `ANTHROPIC_BASE_URL` 을
  전역으로 돌리면 평소 계정 트래픽까지 제3자 프로바이더로 새므로, 라우팅은 켜지 않는다.
  이 기본값을 바꾸려면 사용자에게 먼저 묻는다.
- `skills/` 는 정션의 실체다. `~/.claude/skills` 에 무엇을 설치하든 여기로 떨어지므로,
  제3자 스킬이 저절로 미추적 파일로 나타날 수 있다. 커밋 전에 출처를 확인한다.

### Testing Requirements
- 셸 스크립트는 `bash -n <file>` 로 문법 확인. 실행 테스트는 재실행 안전성이
  전제이므로(모든 스크립트가 멱등하게 작성돼 있다) 같은 머신에서 두 번 돌려 본다.
- `settings.json` 을 건드렸으면 `node -e 'JSON.parse(...)'` 로 유효성을 확인한다.

### Common Patterns
- 훅과 설치 스크립트는 **멱등**하다. 이미 있으면 건너뛰고, 실패해도 세션을 죽이지 않는다
  (`exit 0`).
- 로그는 `${TMPDIR:-/tmp}/<이름>.log` 로 빼고, 콘솔에는 한 줄 요약만 남긴다.
- 주석은 "무엇을" 이 아니라 "왜" 를 적는다. 특히 우회책은 배경을 함께 남긴다.

## Dependencies

### External
- Claude Code (native, Windows) — 이 저장소가 설정하는 대상
- `bun` — 텔레그램 MCP 서버 런타임
- `uv` 또는 `pip3` — `setup.sh` 4단계가 Headroom CLI(`headroom-ai`)를 까는 경로
- `npx skills` — 개인 스킬 설치 경로
- GitHub 원격: https://github.com/moonlust-debug/claude

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
