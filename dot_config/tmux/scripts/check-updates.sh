#!/usr/bin/env bash
# Background-poll chezmoi for pending updates and write a presence-only
# indicator that the tmux status bar consumes. Designed to be cheap,
# non-blocking, and tolerant of offline state.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi"
STATE_FILE="${STATE_DIR}/update-status"
mkdir -p "$STATE_DIR"

# Best-effort fetch. On failure (no network, etc.) we keep the last known
# value rather than blanking it — avoids "all good" lies when offline.
if ! chezmoi git -- fetch --quiet 2>/dev/null; then
  exit 0
fi

behind=$(chezmoi git -- rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)
dirty=$(chezmoi status 2>/dev/null | grep -c . || true)

if [ "$behind" -eq 0 ] && [ "$dirty" -eq 0 ]; then
  : > "$STATE_FILE"
else
  printf '  ' > "$STATE_FILE"
fi
