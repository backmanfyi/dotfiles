#!/usr/bin/env bash
# This script has been retired. The dotfiles are now managed by chezmoi.
#
# Fresh machine:
#   sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply backmanfyi/dotfiles
#
# Daily use:
#   chezmoi update -v      # pull remote changes and apply
#   chezmoi status         # show pending differences
#   chezmoi edit FILE      # edit a managed file (auto-applies on save)
#
# Migration plan and rationale: docs/chezmoi-migration.md

cat <<'EOF' >&2
setup.sh has been retired. Use chezmoi instead.

  Fresh machine:
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply backmanfyi/dotfiles

  Existing machine:
    chezmoi update -v

See docs/chezmoi-migration.md for the migration details.
EOF
exit 1
