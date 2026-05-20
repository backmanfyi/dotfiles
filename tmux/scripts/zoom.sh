#!/bin/bash
# Track Ghostty font-size changes triggered via CMD+= / CMD+- / CMD+0.
# Ghostty performs the actual font change; this script mirrors the value in a
# state file so the tmux status bar can display it.
set -eu

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_FILE="$STATE_DIR/ghostty-zoom"
BASE=12
MIN=4
MAX=72

mkdir -p "$STATE_DIR"

current=$(cat "$STATE_FILE" 2>/dev/null || echo "$BASE")
case "$current" in
  ''|*[!0-9]*) current=$BASE ;;
esac

case "${1:-}" in
  in)    new=$((current + 1)) ;;
  out)   new=$((current - 1)) ;;
  reset) new=$BASE ;;
  *)     echo "usage: ${0##*/} in|out|reset" >&2; exit 1 ;;
esac

if [ "$new" -lt "$MIN" ]; then new=$MIN; fi
if [ "$new" -gt "$MAX" ]; then new=$MAX; fi

echo "$new" > "$STATE_FILE"

tmux refresh-client -S 2>/dev/null || true
