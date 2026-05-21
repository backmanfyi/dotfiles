#!/usr/bin/env bash
# Remove legacy ~/.zshrc and ~/.zshenv left behind from before the ZDOTDIR
# config. With ZDOTDIR set, ~/.zshrc is never sourced — only causes confusion.
set -euo pipefail

for f in "${HOME}/.zshrc" "${HOME}/.zshenv"; do
  if [[ -f "${f}" && ! -L "${f}" ]]; then
    rm "${f}"
  fi
done
