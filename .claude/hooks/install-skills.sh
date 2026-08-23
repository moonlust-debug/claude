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

[ ${#installed[@]} -gt 0 ] && echo "skills: installed ${installed[*]}."
# Never fail the session over this — a missing skill is not a broken session.
[ ${#failed[@]} -gt 0 ] && echo "skills: could not install ${failed[*]}. See $LOG"

exit 0
