#!/bin/sh
# PreToolUse hook (Bash matcher): HARD-BLOCK any `git push` that targets a
# protected branch (main/master). Deterministic backstop for the CLAUDE.md
# "never push to main" rule — advisory prose can be ignored; this cannot.
#
# Only real push *invocations* count: the command is split into segments on
# shell separators (&& || ; |) and a segment is evaluated only if its command
# is `git … push`. This avoids false positives when "git push" / "main" merely
# appear inside a quoted argument such as a commit message or PR body.
#
# Denies when:
#   - an explicit refspec targets main/master
#     (git push origin main, git push origin HEAD:main, git push -f origin master), OR
#   - the push has no explicit refspec (bare `git push`, `git push origin`)
#     and the CURRENT branch is main/master.
# Allows every feature-branch push.

CMD=$(jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
[ -z "$CMD" ] && exit 0

deny() {
  jq -nc --arg r "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Split the command into segments, one per shell separator, so only a segment
# whose command is `git … push` gets evaluated.
SEGMENTS=$(printf '%s' "$CMD" | sed -E 's/\|\||&&|;|\|/\
/g')

oldIFS=$IFS
IFS='
'
set -f
for seg in $SEGMENTS; do
  seg=$(printf '%s' "$seg" | sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//')

  # Strip leading VAR=value env assignments (e.g. `GIT_SSH=… git push …`).
  while printf '%s' "$seg" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+'; do
    seg=$(printf '%s' "$seg" | sed -E 's/^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]*//')
  done

  # The segment's command must be `git`.
  case "$seg" in
    git | git\ *) ;;
    *) continue ;;
  esac
  rest=$(printf '%s' "$seg" | sed -E 's/^git[[:space:]]+//')

  # Strip git global options; value-taking ones consume the following token.
  while :; do
    case "$rest" in
      -C\ * | -c\ * | --git-dir\ * | --work-tree\ * | --namespace\ * | --exec-path\ *)
        rest=$(printf '%s' "$rest" | sed -E 's/^[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+//') ;;
      -*)
        rest=$(printf '%s' "$rest" | sed -E 's/^[^[:space:]]+[[:space:]]+//') ;;
      *) break ;;
    esac
  done

  # The git subcommand must be `push`.
  case "$rest" in
    push | push\ *) ;;
    *) continue ;;
  esac
  pushargs=$(printf '%s' "$rest" | sed -E 's/^push//')

  # 1. Explicit main/master target anywhere in the refspec args.
  if printf '%s' "$pushargs" | grep -qE '(^|[[:space:]:/])(main|master)([[:space:]:]|$)'; then
    deny "Blocked: push targets a protected branch (main/master). Per CLAUDE.md, never push to main — open a feature branch and a PR instead."
  fi

  # 2. No explicit refspec (<=1 positional) while HEAD is protected => bare push
  #    would publish main/master.
  poscount=$(printf '%s' "$pushargs" | tr ' ' '\n' | grep -vE '^-' | grep -cvE '^$')
  if [ "$poscount" -le 1 ]; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    case "$branch" in
      main | master)
        deny "Blocked: bare 'git push' while on '$branch' would publish a protected branch. Per CLAUDE.md, never push to main — switch to a feature branch."
        ;;
    esac
  fi
done
IFS=$oldIFS
set +f
exit 0
