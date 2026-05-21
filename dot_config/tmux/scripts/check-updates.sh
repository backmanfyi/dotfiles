#!/usr/bin/env bash
# Background-poll the dotfiles remote for new commits on main and write a
# presence-only indicator that the tmux status bar consumes. Designed to be
# cheap, non-blocking, and tolerant of offline state.
#
# Compares local main against origin/main directly — independent of the
# currently checked-out branch, so the indicator means "main has commits
# I haven't pulled" regardless of what feature branch you're on.
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi"
STATE_FILE="${STATE_DIR}/update-status"
mkdir -p "$STATE_DIR"

# Best-effort fetch of just origin/main. On failure (no network, etc.) we
# keep the last known value rather than blanking it — avoids "all good"
# lies when offline.
if ! chezmoi git -- fetch --quiet origin main 2>/dev/null; then
  exit 0
fi

behind=$(chezmoi git -- rev-list --count main..origin/main 2>/dev/null || echo 0)

if [ "$behind" -eq 0 ]; then
  : > "$STATE_FILE"
else
  printf '  ' > "$STATE_FILE"
fi
