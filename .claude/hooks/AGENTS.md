<!-- Parent: ../../AGENTS.md -->
<!-- Generated: 2026-08-25 | Updated: 2026-08-25 -->

# hooks

## Purpose
`.claude/settings.json` 의 `SessionStart` 훅으로 등록된 설치 스크립트들이다.
웹/원격 세션은 매번 새 컨테이너로 뜨기 때문에 전 세션에서 설치한 것이 남아 있지 않다.
두 스크립트 모두 "없으면 설치하고, 있으면 즉시 빠져나온다"는 형태라 로컬 세션에서는
비용이 사실상 0이다.

## Key Files
| File | Description |
|------|-------------|
| `install-skills.sh` | 개인 스킬 확보. ①`npx skills add` 로 원격 스킬 설치(현재 `anthropics/skills:skill-creator`) ②저장소의 `skills/` 를 `$SKILLS_DIR` 로 복사 |
| `install-video-deps.sh` | `/watch` 플러그인(watch@claude-video)이 필요한 `ffmpeg`·`ffprobe`·`yt-dlp` 확보 |

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
- 두 번째 루프는 저장소의 `skills/` 를 `$SKILLS_DIR` 로 복사한다. 웹 세션은 저장소를
  클론해 오지만 Claude Code 는 `skills/` 를 스킬 경로로 보지 않기 때문이다. PC 에서는
  `$SKILLS_DIR` 자체가 `skills/` 를 가리키는 정션이라 존재 확인에서 그대로 걸러지므로
  자기 자신을 덮어쓰지 않는다. **이 저장소에 새 개인 스킬을 넣으면 자동으로 따라온다 —
  배열에 손댈 필요 없다.**

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
