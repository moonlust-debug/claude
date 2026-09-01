#!/usr/bin/env bash
# SessionStart hook: install personal preferences into the user-level CLAUDE.md.
#
# The repo root CLAUDE.md only applies while working in this repo. Preferences
# that should hold in *every* project belong in ~/.claude/CLAUDE.md, which a
# fresh web-session container does not have. This copies `user-memory.md` there.
#
# The target may already hold notes written by hand, so only the block between
# the markers below is touched — everything else is preserved byte for byte.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/install-user-memory.log"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/user-memory.md"
DEST="$HOME/.claude/CLAUDE.md"

BEGIN="<!-- BEGIN moonlust-debug/claude -->"
END="<!-- END moonlust-debug/claude -->"

[ -f "$SRC" ] || { echo "user-memory: $SRC 없음, 건너뜀"; exit 0; }

# The block as it should look on disk, marker lines included.
desired="$(printf '%s\n%s\n%s\n' "$BEGIN" "$(cat "$SRC")" "$END")"

# Already correct? Say nothing — re-runs and local sessions must cost nothing.
if [ -f "$DEST" ] && [ "$(awk -v b="$BEGIN" -v e="$END" '
      $0 == b { inside = 1 } inside { print } $0 == e { inside = 0 }
    ' "$DEST")" = "$desired" ]; then
  exit 0
fi

mkdir -p "$(dirname "$DEST")" 2>>"$LOG"

if [ -f "$DEST" ] && grep -qF "$BEGIN" "$DEST" 2>/dev/null; then
  # Stale block: swap its body, leave the surrounding file untouched.
  tmp="$(mktemp)" || { echo "user-memory: mktemp 실패. $LOG 참고"; exit 0; }
  awk -v b="$BEGIN" -v e="$END" -v repl="$desired" '
    $0 == b { print repl; inside = 1; next }
    $0 == e { inside = 0; next }
    !inside { print }
  ' "$DEST" >"$tmp" 2>>"$LOG" && mv "$tmp" "$DEST" 2>>"$LOG"
  action="갱신"
else
  # No block yet: append, keeping a blank line between it and any prior content.
  { [ -s "$DEST" ] && printf '\n'; printf '%s\n' "$desired"; } >>"$DEST" 2>>"$LOG"
  action="설치"
fi

if grep -qF "$BEGIN" "$DEST" 2>/dev/null; then
  echo "user-memory: ${action} 완료 ($DEST)"
else
  # Never fail the session over this — a missing preference is not a broken session.
  echo "user-memory: ${action} 실패. $LOG 참고"
fi

exit 0
