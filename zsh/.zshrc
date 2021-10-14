# Create ZSH cache directory unless it already exists
[[ -d $ZSH_CACHE_DIR ]] || mkdir -p $ZSH_CACHE_DIR

# Vi mode
bindkey -v
export KEYTIMEOUT=1

# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git colored-man-pages osx)

# enable color support for ls, less and man
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
    alias diff='diff --color=auto'
    alias ip='ip --color=auto'

    export LESS_TERMCAP_mb=$'\E[1;31m'     # begin blink
    export LESS_TERMCAP_md=$'\E[1;36m'     # begin bold
    export LESS_TERMCAP_me=$'\E[0m'        # reset bold/blink
    export LESS_TERMCAP_so=$'\E[01;33m'    # begin reverse video
    export LESS_TERMCAP_se=$'\E[0m'        # reset reverse video
    export LESS_TERMCAP_us=$'\E[1;32m'     # begin underline
    export LESS_TERMCAP_ue=$'\E[0m'        # reset underline

    # Take advantage of $LS_COLORS for completion as well
    zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
fi

# Start tmux
if [[ $TMUX = "" ]] then
  tmuxinator start Main -p ~/.config/tmuxinator/main.yml \
    --suppress-tmux-version-warning=SUPPRESS-TMUX-VERSION-WARNING--suppress-tmux-version-warning=SUPPRESS-TMUX-VERSION-WARNING
  tmuxinator start notes -p ~/.config/tmuxinator/notes.yml \
    --no-attach --suppress-tmux-version-warning=SUPPRESS-TMUX-VERSION-WARNING--suppress-tmux-version-warning=SUPPRESS-TMUX-VERSION-WARNING
fi

# Source oh-my-zsh
source $ZSH/oh-my-zsh.sh

# Alias
alias docker-up='docker-machine start default && eval "$(docker-machine env default)"'
# nvim
alias vim='nvim'
alias vi='nvim'
alias vimdiff='nvim -d'
alias vis='EDITOR=vim visudo -f'
# Remap old commands
alias ls='exa'
alias ll='exa -l'
alias lla='exa -al'
alias tree='exa -T'
alias cat='bat'
alias assume-role='${XDG_CONFIG_HOME}/tmux/scripts/assume-role.sh'

# SSH
if [ -s "${XDG_CONFIG_HOME}/ssh/config" ]
then
  SSH_CONFIG="-F ${XDG_CONFIG_HOME}/ssh/config"
fi
if [ -s "${XDG_CONFIG_HOME}/ssh/id_dsa" ]
then
  SSH_ID="-i ${XDG_CONFIG_HOME}/ssh/id_ed25519"
fi
alias ssh="/usr/local/bin/ssh $SSH_CONFIG $SSH_ID "
alias ssh-keygen="/usr/local/bin/ssh-keygen"
alias ssh-agent="/usr/local/bin/ssh-agent"
alias ssh-add="/usr/local/bin/ssh-add"

# Docker Aliases
alias flake="docker run -ti --rm -v \$(pwd):/apps alpine/flake8:latest"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/lars.backman/Documents/Tickets/SEC-2001/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/lars.backman/Documents/Tickets/SEC-2001/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/lars.backman/Documents/Tickets/SEC-2001/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/lars.backman/Documents/Tickets/SEC-2001/google-cloud-sdk/completion.zsh.inc'; fi
#!/bin/bash

# Realpath
realpath() {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

realpath "$0"
