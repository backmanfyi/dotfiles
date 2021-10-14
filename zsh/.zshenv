# -*- mode: sh; -*-

# Locale
export LC_ALL=en_GB.UTF-8
export LC_CTYPE=en_GB.UTF-8
export LANG=en_GB.UTF-8

export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share

# EDITOR
unset ALTERNATE_EDITOR
export EDITOR='nvim'
export PAGER='less -M'
export VISUAL=$EDITOR

# ZSH
export ZSH_THEME="philips"
export ZSH=$XDG_DATA_HOME"/oh-my-zsh"
export ZSH_CUSTOM=$ZDOTDIR/custom
export ZSH_CACHE_DIR=$XDG_CACHE_HOME/zsh
export HISTFILE=$ZSH_CACHE_DIR/zhistory
export ZDOTDIR=$XDG_CONFIG_HOME/zsh

# SSH
export GIT_SSH_COMMAND="/usr/local/bin/ssh -F ${XDG_CONFIG_HOME}/ssh/config"

# Completions
fpath+=($ZDOTDIR/completions)


