<!-- Parent: ../../AGENTS.md -->
<!-- Generated: 2026-08-25 | Updated: 2026-09-01 -->

# hooks

## Purpose
세션 시작 시 필요한 것을 확보하는 설치 스크립트들이다. 웹/원격 세션은 매번 새
컨테이너로 뜨기 때문에 전 세션에서 설치한 것이 남아 있지 않다. 모두 "없으면
설치하고, 있으면 즉시 빠져나온다"는 형태라 로컬 세션에서는 비용이 사실상 0이다.

전부가 `SessionStart` 에 등록돼 있는 것은 아니다. 등록 여부는 아래 표를 보고,
실제 확인은 `jq -r '.hooks.SessionStart[0].hooks[].command' .claude/settings.json`
으로 한다.

## Key Files
| File | 등록 | Description |
|------|------|-------------|
| `install-skills.sh` | O | `npx skills add` 로 개인 스킬 설치. 현재 대상은 `anthropics/skills:skill-creator` |
| `install-video-deps.sh` | O | `/watch` 플러그인(watch@claude-video)이 필요한 `ffmpeg`·`ffprobe`·`yt-dlp` 확보 |
| `install-user-memory.sh` | **X** | `user-memory.md` 를 `~/.claude/CLAUDE.md` 의 마커 블록에 반영. 미등록이라 수동 실행해야 한다 |
| `user-memory.md` | — | 위 스크립트가 설치하는 전역 설정 원본. 스크립트가 아니라 데이터다 |

`install-user-memory.sh` 가 미등록인 이유: 등록하려면 `.claude/settings.json` 을
고쳐야 하는데 그 파일이 deny 목록(`Edit(./.claude/settings.json)`)에 있어 에이전트가
쓰지 못한다. 사람이 직접 `hooks.SessionStart[0].hooks` 배열에 항목을 추가하면 된다.
그때까지는 새 컨테이너마다 `bash .claude/hooks/install-user-memory.sh` 를 한 번 돌린다.

## Subdirectories
없음.

## For AI Agents

### Working In This Directory
- **세션을 죽이지 말 것.** 두 스크립트 모두 마지막이 `exit 0` 이고 `set -e` 를 쓰지
  않는다(`set -uo pipefail` 만). 설치 실패는 경고 한 줄로 끝나야지 세션 시작을
  막아서는 안 된다. 이 성질을 깨는 수정은 하지 않는다.
- `install-skills.sh` 의 `SKILLS_DIR` 은 `$HOME/.claude/skills` 로 두어야 한다.
  이 머신에서는 그 경로가 `D:\claude\skills` 를 가리키는 정션이라 결과적으로 D: 에
  떨어지지만, D: 가 없는 웹 세션에서도 같은 스크립트가 동작해야 하므로 하드코딩하지 않는다.
- 새 스킬을 추가할 때는 `SKILLS` 배열에 `repo:skill` 한 줄만 넣는다.
- `install-user-memory.sh` 는 `~/.claude/CLAUDE.md` 를 통째로 쓰지 않는다.
  `<!-- BEGIN moonlust-debug/claude -->` ~ `<!-- END ... -->` 사이만 교체하고
  나머지는 그대로 둔다. 그 파일에는 손으로 쓴 전역 메모리가 있을 수 있으므로,
  이 성질을 깨는 수정(전체 덮어쓰기, 마커 제거)은 하지 않는다.
- 전역 설정 문구를 바꿀 때는 `user-memory.md` 만 고친다. 스크립트는 손댈 필요가 없다.
  단, 저장소 루트 `CLAUDE.md`(이 저장소 한정)와는 별개 파일이라 함께 고쳐야 한다.

### Testing Requirements
- `bash -n <file>` 로 문법 확인.
- 두 번 연속 실행해 두 번째가 아무 출력 없이 끝나는지(멱등성) 확인한다.
- 훅 등록 자체는 `.claude/settings.json` 의 `hooks.SessionStart` 에 있다.
  스크립트 이름을 바꾸면 그쪽도 함께 고쳐야 한다.

### Common Patterns
- 존재 확인은 `command -v` 를 감싼 `have()` 헬퍼로 한다.
- 시끄러운 출력은 `${TMPDIR:-/tmp}/<이름>.log` 로 보내고 콘솔에는 요약만 남긴다.
- 설치 결과를 `installed`/`failed` 배열에 모아 끝에서 한 번에 보고한다.
- 설치 경로가 PATH 에 없을 수 있으므로(`uv tool install` → `~/.local/bin`),
  설치 후 반드시 바이너리가 실제로 잡히는지 다시 확인하고 필요하면 대체 경로를 쓴다.

## Dependencies

### Internal
- `../settings.json` — 이 스크립트들을 `SessionStart` 훅으로 등록하는 곳
- `../../skills/` — `install-skills.sh` 의 설치 결과가 도달하는 실체 디렉터리

### External
- `npx skills` (skills CLI), `uv` 또는 `pip3`, `apt-get` 또는 `brew`

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
