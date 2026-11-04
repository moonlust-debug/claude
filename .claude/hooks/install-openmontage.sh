#!/usr/bin/env bash
# SessionStart hook: make sure OpenMontage (calesthio/OpenMontage) is cloned
# and set up, so the ai-video-gen skill has its tool registry, Remotion
# composer and Piper TTS behind it.
#
# OpenMontage is not a skill but a workspace you open Claude Code in, and its
# `make setup` (pip requirements + `npm install` + piper-tts) takes minutes.
# Running it in the foreground would hold up every fresh web session, so setup
# goes to the background and the hook returns immediately.
#
# API keys live in $OM_DIR/.env (created from .env.example by setup). It is
# not in this repo on purpose, so keys still have to be added per machine.
set -uo pipefail

OM_DIR="${OPENMONTAGE_DIR:-$HOME/OpenMontage}"
LOG="${TMPDIR:-/tmp}/install-openmontage.log"

have() { command -v "$1" >/dev/null 2>&1; }

# Done = venv python and the Remotion composer's node_modules both exist.
if { [ -x "$OM_DIR/.venv/bin/python" ] || [ -x "$OM_DIR/.venv/Scripts/python.exe" ]; } \
  && [ -d "$OM_DIR/remotion-composer/node_modules" ]; then
  exit 0
fi

for tool in git make npm; do
  if ! have "$tool"; then
    echo "openmontage: $tool not found, skipping."
    exit 0
  fi
done

if [ ! -d "$OM_DIR/.git" ]; then
  if ! git clone -q --depth 1 https://github.com/calesthio/OpenMontage.git "$OM_DIR" >"$LOG" 2>&1; then
    echo "openmontage: clone failed. See $LOG"
    exit 0
  fi
fi

# A second session (or /clear) can start before the background setup finishes;
# two `make setup` runs on one venv and node_modules would trample each other.
PIDFILE="$OM_DIR/.setup.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  echo "openmontage: setup still running. See $LOG"
  exit 0
fi

nohup make -C "$OM_DIR" setup >>"$LOG" 2>&1 </dev/null &
echo $! >"$PIDFILE"
echo "openmontage: setting up in $OM_DIR in the background. See $LOG"
exit 0
