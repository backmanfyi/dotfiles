#!/bin/bash
# Emit " · PROFILE · ROLE" when AWS_PROFILE is set in the tmux environment,
# nothing otherwise. Designed to be embedded directly in status-left.
set -eu

profile_line=$(tmux show-environment AWS_PROFILE 2>/dev/null || true)
case "$profile_line" in
  AWS_PROFILE=*) profile="${profile_line#AWS_PROFILE=}" ;;
  *) exit 0 ;;
esac

[ -z "$profile" ] && exit 0

role_line=$(tmux show-environment AWS_ROLE 2>/dev/null || true)
case "$role_line" in
  AWS_ROLE=*) role="${role_line#AWS_ROLE=}" ;;
  *) role="" ;;
esac

profile_upper=$(printf '%s' "$profile" | tr '[:lower:]' '[:upper:]')

if [ -n "$role" ]; then
  printf ' · %s · %s' "$profile_upper" "$role"
else
  printf ' · %s' "$profile_upper"
fi
