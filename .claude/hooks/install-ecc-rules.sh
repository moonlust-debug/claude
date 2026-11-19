#!/usr/bin/env bash
# SessionStart hook: copy the pinned ECC rules (rules/ecc in this repo) into
# ~/.claude/rules/ecc so they apply in every directory, not just this repo.
#
# The ecc@ecc plugin cannot ship rules, and web sessions start from a fresh
# container, so the user-level copy is gone each time. The source is a pinned,
# reviewed copy in the repo rather than a live clone: rules are injected into
# every session's context, so upstream changes must not land unreviewed.
set -uo pipefail

SRC="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/rules/ecc"
DEST="$HOME/.claude/rules/ecc"
PACKS=(common python typescript react web golang)

[ -d "$SRC" ] || exit 0

updated=()
for pack in "${PACKS[@]}"; do
  [ -d "$SRC/$pack" ] || continue
  # Already identical → nothing to do (keeps repeat runs silent).
  if [ -d "$DEST/$pack" ] && diff -rq "$SRC/$pack" "$DEST/$pack" >/dev/null 2>&1; then
    continue
  fi
  mkdir -p "$DEST/$pack" && cp -R "$SRC/$pack/." "$DEST/$pack/" && updated+=("$pack")
done

if [ "${#updated[@]}" -gt 0 ]; then
  echo "ecc rules: installed ${updated[*]} → $DEST"
fi

exit 0
