#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${HOME}/.config/dotfiles"
REPO="git@github.com:backmanfyi/dotfiles.git"

# Install chezmoi if not present
if ! command -v chezmoi >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install chezmoi
  else
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "${HOME}/.local/bin"
    export PATH="${HOME}/.local/bin:${PATH}"
  fi
fi

# Clone the repo if not already present
if [[ ! -d "${DOTFILES_DIR}/.git" ]]; then
  git clone "${REPO}" "${DOTFILES_DIR}"
fi

exec chezmoi init --apply --source "${DOTFILES_DIR}"
