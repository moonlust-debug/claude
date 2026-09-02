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
| `README.md` | 제목 한 줄뿐인 자리표시자 |
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
- `npx skills` — 개인 스킬 설치 경로
- GitHub 원격: https://github.com/moonlust-debug/claude

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
