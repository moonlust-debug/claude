#!/usr/bin/env bash
# SessionStart hook: install personal skills that do not ship with the session.
#
# Web sessions get a fresh container every time, so anything installed with
# `npx skills add` is gone on the next start. Each entry below is skipped when
# the skill is already on disk, so local sessions and re-runs cost nothing.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/install-skills.log"
SKILLS_DIR="$HOME/.claude/skills"

# repo:skill pairs to install, one per line.
SKILLS=(
  "anthropics/skills:skill-creator"
)

installed=()
failed=()

for entry in "${SKILLS[@]}"; do
  repo="${entry%%:*}"
  skill="${entry##*:}"

  [ -f "$SKILLS_DIR/$skill/SKILL.md" ] && continue

  npx --yes skills add "$repo" --skill "$skill" --agent claude-code --global >>"$LOG" 2>&1

  if [ -f "$SKILLS_DIR/$skill/SKILL.md" ]; then
    installed+=("$skill")
  else
    failed+=("$skill")
  fi
done

# 이 저장소가 들고 다니는 개인 스킬(../../skills/)도 심는다.
# 웹 세션은 저장소를 클론해 오지만 Claude Code 는 skills/ 를 스킬 경로로 보지 않는다.
# PC 에서는 $SKILLS_DIR 자체가 이 폴더를 가리키는 정션이라 이미 존재하므로 그대로 걸러진다.
REPO_SKILLS="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/skills"

for dir in "$REPO_SKILLS"/*/; do
  skill="$(basename "$dir")"

  [ -f "$dir/SKILL.md" ] || continue
  [ -f "$SKILLS_DIR/$skill/SKILL.md" ] && continue

  if mkdir -p "$SKILLS_DIR" && cp -R "${dir%/}" "$SKILLS_DIR/" >>"$LOG" 2>&1; then
    installed+=("$skill")
  else
    failed+=("$skill")
  fi
done

[ ${#installed[@]} -gt 0 ] && echo "skills: installed ${installed[*]}."
# Never fail the session over this — a missing skill is not a broken session.
[ ${#failed[@]} -gt 0 ] && echo "skills: could not install ${failed[*]}. See $LOG"

exit 0
