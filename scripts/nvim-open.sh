#!/usr/bin/env bash
# nvim-open.sh — opens files in nvim in a dedicated tmux session.
# If Ghostty is running, switches its tmux client to the new session.
# If not, opens a new Ghostty window attached to it.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="${HOME:-/Users/$(id -un)}"

TMUX_BIN=/opt/homebrew/bin/tmux
NVIM=/opt/homebrew/bin/nvim
filepath="$1"

[[ -z "$filepath" ]] && exit 1

# Stable, unique session name — same file always maps to the same session
base="$(basename "$filepath" | tr ' ./:' '____')"
hash="$(echo "$filepath" | shasum | cut -c1-6)"
session_name="${base}_${hash}"
escaped=$(printf '%q' "$filepath")

# Create the tmux session (or reuse if the file is already open)
if ! $TMUX_BIN has-session -t "$session_name" 2>/dev/null; then
  $TMUX_BIN new-session -d -s "$session_name" -x 220 -y 50 "exec $NVIM -- $escaped"
fi

# Check if Ghostty is already running
if pgrep -x ghostty >/dev/null 2>&1; then
  # Switch the active tmux client to the new session
  client=$($TMUX_BIN list-clients -F '#{client_name}' 2>/dev/null | head -1)
  if [[ -n "$client" ]]; then
    $TMUX_BIN switch-client -c "$client" -t "$session_name"
  fi
  # Bring Ghostty to the foreground
  osascript -e 'tell application "Ghostty" to activate'
else
  # Ghostty not running — open it and attach to the new session
  open -a Ghostty --args \
    --quit-after-last-window-closed=true \
    -e "$TMUX_BIN" attach-session -t "$session_name"
fi

