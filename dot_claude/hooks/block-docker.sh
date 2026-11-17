#!/bin/sh
# PreToolUse hook (Bash matcher): HARD-BLOCK any `docker` / `docker-compose`
# invocation. Deterministic backstop for the CLAUDE.md "use podman, never
# docker" rule.
#
# Only real invocations count: the command is split on shell separators
# (&& || ; |) and a segment is denied only when its command word is docker,
# after stripping leading env assignments and `sudo`. "docker" inside a quoted
# argument, a path or a filename (Dockerfile) does not trigger it.

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

SEGMENTS=$(printf '%s' "$CMD" | sed -E 's/\|\||&&|;|\|/\
/g')

oldIFS=$IFS
IFS='
'
set -f
for seg in $SEGMENTS; do
  seg=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')
  while printf '%s' "$seg" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+'; do
    seg=$(printf '%s' "$seg" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]*//')
  done
  seg=$(printf '%s' "$seg" | sed -E 's/^(sudo|command|exec)[[:space:]]+//')
  case "$seg" in
    docker | docker\ * | docker-compose | docker-compose\ *)
      jq -nc '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"Blocked: use podman, never docker (global CLAUDE.md). Rerun the command with podman (podman compose for compose files)."}}'
      exit 0
      ;;
  esac
done
IFS=$oldIFS
set +f
exit 0
