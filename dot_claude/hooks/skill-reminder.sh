#!/bin/sh
# PreToolUse hook (Bash matcher): nudges toward the right skill when the
# command-head is one of the gated git operations. Emits additionalContext
# JSON; never blocks. Stays warn-only.
#
# Lives at user level because the same skills are in use across every Claude
# Code session that operates in the backmanfyi monorepo (and any future repo
# adopting the same skill names).
#
# Matching rule: only nudges if the command STARTS WITH the gated phrase.
# This avoids false positives when commit messages or PR bodies contain the
# literal string (which bit us repeatedly before the rewrite).

set -e

CMD=$(python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || true)

# Strip leading whitespace and any pre-command env var assignments (e.g.
# `FOO=bar git push ...`). Cheap heuristic — drop tokens containing '='
# until we find one that doesn't.
CMD=$(echo "$CMD" | sed -E 's/^[[:space:]]+//')
while echo "$CMD" | head -c 64 | grep -qE '^[A-Z_]+=[^[:space:]]+[[:space:]]+'; do
  CMD=$(echo "$CMD" | sed -E 's/^[A-Z_]+=[^[:space:]]+[[:space:]]+//')
done

case "$CMD" in
  "git push"*|"git -"*"push "*|*"&& git push"*)
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REMINDER: Use the git-push skill for this git push. Invoke it via the Skill tool (skill name: git-push) — it handles pre-push safety checks, PR creation if missing, CI watch, and the fix-commit-push loop."}}
EOF
    ;;
  "gh pr create"*)
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REMINDER: PR creation is part of the git-push skill now. Invoke /git-push — it handles labels, linked-issue verification, the Closes-keyword formatting rule, and pushes to remote in one flow."}}
EOF
    ;;
  "gh pr merge"*)
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"REMINDER: Use the git-merge skill for this merge. Invoke /git-merge — it runs the validation pipeline (security-review, test-completeness, linked-issue verification), waits for explicit user confirmation, then merges with --auto (worktree-aware) and verifies issue closures."}}
EOF
    ;;
esac

exit 0
