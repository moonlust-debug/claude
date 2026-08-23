#!/usr/bin/env bash
# SessionStart hook: make sure the /watch plugin (watch@claude-video) has the
# binaries it needs.
#
# Web/remote sessions get a fresh container every time, so ffmpeg and yt-dlp
# have to be reinstalled on each start. This is a no-op once they are present,
# so local sessions pay nothing.
set -uo pipefail

LOG="${TMPDIR:-/tmp}/install-video-deps.log"

have() { command -v "$1" >/dev/null 2>&1; }

# Fast path: everything the plugin's own preflight checks for is already here.
if have ffmpeg && have ffprobe && have yt-dlp; then
  exit 0
fi

missing=()
have yt-dlp || missing+=("yt-dlp")
{ have ffmpeg && have ffprobe; } || missing+=("ffmpeg")
echo "/watch deps: installing ${missing[*]}…"

: >"$LOG"

if ! have yt-dlp; then
  # uv is fastest when present, but it installs into ~/.local/bin, which is not
  # on PATH everywhere — fall back to pip if the binary still is not resolvable.
  have uv && uv tool install yt-dlp >>"$LOG" 2>&1
  if ! have yt-dlp; then
    pip3 install --quiet --break-system-packages yt-dlp >>"$LOG" 2>&1 ||
      pip3 install --quiet yt-dlp >>"$LOG" 2>&1
  fi
fi

if ! have ffmpeg || ! have ffprobe; then
  if have apt-get && [ "$(id -u)" -eq 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq >>"$LOG" 2>&1 &&
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends ffmpeg >>"$LOG" 2>&1
  elif have brew; then
    brew install ffmpeg >>"$LOG" 2>&1
  fi
fi

still=()
have yt-dlp || still+=("yt-dlp")
{ have ffmpeg && have ffprobe; } || still+=("ffmpeg")

if [ ${#still[@]} -eq 0 ]; then
  echo "/watch deps: ready (ffmpeg, ffprobe, yt-dlp)."
else
  # Never fail the session over this — /watch just reports what is missing.
  echo "/watch deps: could not install ${still[*]}. See $LOG"
fi

exit 0
