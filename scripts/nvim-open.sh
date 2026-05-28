#!/usr/bin/env bash
# nvim-open.sh — macOS file handler: opens files in nvim inside a tmux session in Ghostty
# Called by NvimOpen.app (Platypus wrapper) with $1 = absolute file path

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="${HOME:-/Users/$(id -un)}"

TMUX=/opt/homebrew/bin/tmux
NVIM=/opt/homebrew/bin/nvim
filepath="$1"

if [[ -z "$filepath" ]]; then
  exit 1
fi

# Stable session name: human-readable basename + short hash of full path
# Same file always maps to the same session — enables reattach-if-open behaviour
base="$(basename "$filepath" | tr ' ./:' '____')"
hash="$(echo "$filepath" | md5 | cut -c1-6)"
session_name="${base}_${hash}"

escaped=$(printf '%q' "$filepath")

# Create a detached tmux session running nvim, or reattach if already open
if ! $TMUX has-session -t "$session_name" 2>/dev/null; then
  $TMUX new-session -d -s "$session_name" -x 220 -y 50 \
    "exec $NVIM -- $escaped"
fi

# Open a new Ghostty window attached to the tmux session
# --quit-after-last-window-closed prevents orphaned Ghostty processes
open -na Ghostty --args \
  --quit-after-last-window-closed=true \
  -e $TMUX attach-session -t "$session_name"
