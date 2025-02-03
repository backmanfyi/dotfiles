#! /bin/bash

CONFIG_DIR="${HOME}/.config"

# ZSH
ZDOTDIR="${CONFIG_DIR}/zsh"
mkdir -p $ZDOTDIR

if [ ! -L "${ZDOTDIR}/.zshrc" ]; then
  ln -s $(pwd)/zsh/zshrc "${ZDOTDIR}/.zshrc"
  ln -s $(pwd)/zsh/zshenv "${ZDOTDIR}/.zshenv"
fi

declare -a configs=("bat" "ghostty" "git" "nvim" "ssh" "starship" "tmux")

for config in "${configs[@]}"; do
  if [ ! -L "${CONFIG_DIR}/${config}" ]; then
    ln -s $(pwd)/${config} "${CONFIG_DIR}/${config}"
  fi
done
