#!/usr/bin/env bash
# SessionStart hook: make sure the Codex CLI is installed so ChatGPT image
# generation (`codex exec` + the built-in image_generation tool) is one command
# away.
#
# Web/remote sessions get a fresh container every time, so the global npm
# package is gone on each start. Login (~/.codex/auth.json) does not survive
# either — that still needs `codex login --device-auth` once per container.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/install-codex.log"

have() { command -v "$1" >/dev/null 2>&1; }

if have codex; then
  exit 0
fi

if ! have npm; then
  echo "codex: npm not found, skipping."
  exit 0
fi

echo "codex: installing @openai/codex…"
npm install -g @openai/codex >"$LOG" 2>&1

if have codex; then
  echo "codex: ready ($(codex --version 2>/dev/null))."
else
  echo "codex: install failed. See $LOG"
fi

exit 0
