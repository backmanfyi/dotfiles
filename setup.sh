#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${HOME}/.config"
BREW_ZSH="/opt/homebrew/bin/zsh"

DRY_RUN=false

# ── Output helpers ────────────────────────────────────────────────────────────

# Disable colours in CI or when not a terminal
if [[ -t 1 && "${CI:-}" != "true" ]]; then
  BLUE='\033[34m' GREEN='\033[32m' YELLOW='\033[33m' RED='\033[31m' DIM='\033[90m' RESET='\033[0m'
else
  BLUE='' GREEN='' YELLOW='' RED='' DIM='' RESET=''
fi

info()  { printf "  ${BLUE}→${RESET}  %s\n" "$*"; }
ok()    { printf "  ${GREEN}✓${RESET}  %s\n" "$*"; }
warn()  { printf "  ${YELLOW}!${RESET}  %s\n" "$*" >&2; }
die()   { printf "  ${RED}✗${RESET}  %s\n" "$*" >&2; exit 1; }
dry()   { printf "  ${DIM}~${RESET}  would run: %s\n" "$*"; }
header(){ printf "\n${DIM}── %s ${RESET}\n\n" "$*"; }

# run: executes the command, or prints it in dry-run mode
run() {
  if $DRY_RUN; then
    dry "$*"
  else
    "$@"
  fi
}

command_exists() { command -v "$1" &>/dev/null; }

# ── Argument parsing ──────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dry-run   Show what would be done without making any changes
  --help      Show this help
EOF
}

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --help)    usage; exit 0 ;;
    *)         die "Unknown argument: ${arg}" ;;
  esac
done

# ── Steps ─────────────────────────────────────────────────────────────────────

# 1. Ensure zsh can find ZDOTDIR on a fresh machine.
# /etc/zshenv is the only file zsh reads before ZDOTDIR is known.
step_zdotdir() {
  header "1/5  ZDOTDIR bootstrap"

  if grep -q "ZDOTDIR" /etc/zshenv 2>/dev/null; then
    ok "ZDOTDIR already set in /etc/zshenv"
    return
  fi

  info "Writing ZDOTDIR to /etc/zshenv (requires sudo)"
  if ! $DRY_RUN; then
    printf '\nexport XDG_CONFIG_HOME="$HOME/.config"\nexport ZDOTDIR="${XDG_CONFIG_HOME}/zsh"\n' \
      | sudo tee -a /etc/zshenv > /dev/null
  else
    dry "sudo tee -a /etc/zshenv <<< 'export ZDOTDIR=...'"
  fi
  ok "ZDOTDIR configured"
}

# 2. Install Homebrew if missing, then install all packages from the Brewfile.
step_homebrew() {
  header "2/5  Homebrew + packages"

  if ! command_exists brew; then
    info "Installing Homebrew"
    if ! $DRY_RUN; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      dry "/bin/bash homebrew-install.sh"
    fi
    ok "Homebrew installed"
  else
    ok "Homebrew $(brew --version | head -1)"
  fi

  info "Running brew bundle"
  run brew bundle --file="${DOTFILES_DIR}/brew/Brewfile"
  ok "Packages installed"
}

# 3. Register the Homebrew-managed zsh as a valid login shell and set it as
# the default. macOS ships an older /bin/zsh; this ensures we use the current one.
step_shell() {
  header "3/5  Login shell"

  if ! grep -qF "${BREW_ZSH}" /etc/shells 2>/dev/null; then
    info "Adding ${BREW_ZSH} to /etc/shells"
    if ! $DRY_RUN; then
      echo "${BREW_ZSH}" | sudo tee -a /etc/shells > /dev/null
    else
      dry "echo ${BREW_ZSH} | sudo tee -a /etc/shells"
    fi
    ok "Registered ${BREW_ZSH}"
  else
    ok "${BREW_ZSH} already in /etc/shells"
  fi

  if [[ "${SHELL:-}" != "${BREW_ZSH}" ]]; then
    info "Changing default shell to ${BREW_ZSH} (you may be prompted for your password)"
    run chsh -s "${BREW_ZSH}"
    ok "Default shell changed to ${BREW_ZSH}"
  else
    ok "Default shell already ${BREW_ZSH}"
  fi
}

# 4. Create symlinks from ~/.config/* to the dotfiles repo.
step_symlinks() {
  header "4/5  Config symlinks"

  local zdotdir="${CONFIG_DIR}/zsh"
  run mkdir -p "${zdotdir}"

  # ZSH — note the dot prefix: .zshrc, .zshenv
  _link "${DOTFILES_DIR}/zsh/zshrc"  "${zdotdir}/.zshrc"
  _link "${DOTFILES_DIR}/zsh/zshenv" "${zdotdir}/.zshenv"

  # Tools
  local -a configs=("bat" "ghostty" "git" "nvim" "ssh" "starship" "tmux")
  for config in "${configs[@]}"; do
    _link "${DOTFILES_DIR}/${config}" "${CONFIG_DIR}/${config}"
  done

  ok "Symlinks in place"
}

# _link <src> <dst>: creates a symlink, skipping with a warning if blocked.
_link() {
  local src="$1" dst="$2"

  # Catch missing source files immediately — indicates a bug in the configs array
  if [[ ! -e "${src}" ]]; then
    die "Source missing: ${src} — cannot create symlink"
  fi

  if [[ -L "${dst}" ]]; then
    local current
    current="$(readlink "${dst}")"
    if [[ "${current}" == "${src}" ]]; then
      info "Already linked: $(basename "${dst}")"
      return
    fi
    warn "$(basename "${dst}") points to ${current} (expected ${src}) — skipping"
    return
  fi

  if [[ -e "${dst}" ]]; then
    warn "${dst} exists and is not a symlink — skipping"
    return
  fi

  info "Linking $(basename "${dst}")"
  run ln -s "${src}" "${dst}"
}

# 5. Git hooks need the executable bit or git silently ignores them.
step_git_hooks() {
  header "5/6  Git hooks"

  local hooks_dir="${DOTFILES_DIR}/git/hooks"
  if [[ ! -d "${hooks_dir}" ]]; then
    warn "No hooks directory found at ${hooks_dir} — skipping"
    return
  fi

  while IFS= read -r -d '' hook; do
    info "chmod +x $(basename "${hook}")"
    run chmod +x "${hook}"
  done < <(find "${hooks_dir}" -type f -print0)
  ok "Git hooks executable"
}

# 6. SSH is strict about config file permissions and silently ignores configs
# with group/world read access.
step_ssh_permissions() {
  header "6/6  SSH permissions"

  local ssh_link="${CONFIG_DIR}/ssh"
  if [[ ! -e "${ssh_link}" ]]; then
    warn "SSH config not found at ${ssh_link} — skipping"
    return
  fi

  local ssh_dir
  ssh_dir="$(realpath "${ssh_link}")"
  info "Securing ${ssh_dir}"
  run chmod 700 "${ssh_dir}"
  while IFS= read -r -d '' f; do
    run chmod 600 "${f}"
  done < <(find "${ssh_dir}" -type f -print0)
  ok "SSH permissions set"
}

# ── Main ──────────────────────────────────────────────────────────────────────

printf "\n  dotfiles setup\n  %s\n" "${DOTFILES_DIR}"
$DRY_RUN && printf "\n  ${YELLOW}DRY RUN — no changes will be made${RESET}\n"

step_zdotdir
step_homebrew
step_shell
step_symlinks
step_git_hooks
step_ssh_permissions

printf "\n${DIM}── done ──────────────────────────────────────────────${RESET}\n\n"
if ! $DRY_RUN; then
  printf "  Restart your terminal to apply all changes.\n\n"
fi
