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

# prompt_for_accessibility <app-name>...: launches each app to trigger the
# TCC prompt, opens the Accessibility settings pane once, and waits for one
# confirmation covering all listed apps. macOS TCC blocks granting Accessibility
# silently — interactive only.
prompt_for_accessibility() {
  local apps_list="$*"

  if $DRY_RUN; then
    dry "launch ${apps_list}; open Accessibility settings; wait for user"
    return
  fi

  if [[ ! -t 0 ]]; then
    warn "Non-interactive shell — grant Accessibility manually for: ${apps_list}"
    return
  fi

  for app in "$@"; do
    info "Launching ${app} to trigger the Accessibility prompt"
    open -a "${app}" 2>/dev/null || warn "Could not launch ${app}"
  done
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true

  printf "\n  ${YELLOW}Action needed:${RESET} enable Accessibility for: ${apps_list}\n"
  read -r -p "  Press enter once enabled (or Ctrl-C to skip)... " _
}

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
  header "1/12  ZDOTDIR bootstrap"

  if grep -qE "^[[:space:]]*export[[:space:]]+ZDOTDIR=" /etc/zshenv 2>/dev/null; then
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
  header "2/12  Homebrew + packages"

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
  run brew bundle --quiet --file="${DOTFILES_DIR}/brew/Brewfile"
  ok "Packages installed"
}

# 3. Register the Homebrew-managed zsh as a valid login shell and set it as
# the default. macOS ships an older /bin/zsh; this ensures we use the current one.
step_shell() {
  header "3/12  Login shell"

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
  header "4/12  Config symlinks"

  local zdotdir="${CONFIG_DIR}/zsh"
  run mkdir -p "${zdotdir}"

  # ZSH — note the dot prefix: .zshrc, .zshenv
  _link "${DOTFILES_DIR}/zsh/zshrc"  "${zdotdir}/.zshrc"
  _link "${DOTFILES_DIR}/zsh/zshenv" "${zdotdir}/.zshenv"

  # Tools
  local -a configs=("aerospace" "bat" "ghostty" "git" "nvim" "ssh" "starship" "tmux")
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

# 5. Symlink Claude Code config — CLAUDE.md, settings.json, and agents/.
# ~/.claude/ is not an XDG dir so these are linked individually rather than
# symlinking the whole directory (which contains runtime state we don't track).
step_claude() {
  header "5/12  Claude Code config"

  local claude_src="${DOTFILES_DIR}/claude"
  local claude_dst="${HOME}/.claude"

  run mkdir -p "${claude_dst}"

  _link "${claude_src}/CLAUDE.md"    "${claude_dst}/CLAUDE.md"
  _link "${claude_src}/settings.json" "${claude_dst}/settings.json"
  _link "${claude_src}/agents"        "${claude_dst}/agents"

  ok "Claude Code config linked"
}

# 6. Git hooks need the executable bit or git silently ignores them.
# Also makes .githooks/ executable — these are repo-local hooks chained
# from the global hook and must be executable to be invoked.
step_git_hooks() {
  header "6/12  Git hooks"

  local -a hook_dirs=("${DOTFILES_DIR}/git/hooks" "${DOTFILES_DIR}/.githooks")

  for hooks_dir in "${hook_dirs[@]}"; do
    [[ -d "${hooks_dir}" ]] || continue
    while IFS= read -r -d '' hook; do
      info "chmod +x $(basename "${hook}")"
      run chmod +x "${hook}"
    done < <(find "${hooks_dir}" -type f -print0)
  done

  ok "Git hooks executable"
}

# 7. Ensure ~/.ssh/config includes the managed dotfiles SSH config.
# ~/.ssh/config is the system default read by all SSH clients; we keep it minimal
# and use Include to pull in the managed config from the dotfiles repo.
# OrbStack's Include must stay first (it adds Host blocks before any Match/Host).
step_ssh_include() {
  header "7/12  SSH include"

  local system_ssh="${HOME}/.ssh/config"
  local managed_include="Include ~/.config/ssh/config"

  run mkdir -p "${HOME}/.ssh"

  if [[ -f "${system_ssh}" ]] && grep -qE "^[[:space:]]*Include[[:space:]]+~/.config/ssh/config" "${system_ssh}" 2>/dev/null; then
    ok "~/.ssh/config already includes managed config"
    return
  fi

  info "Adding managed config Include to ~/.ssh/config"
  if ! $DRY_RUN; then
    printf '\n# Managed dotfiles config — edit at ~/.config/dotfiles/ssh/config\n%s\n' \
      "${managed_include}" >> "${system_ssh}"
  else
    dry "printf '...Include...' >> ${system_ssh}"
  fi
  ok "~/.ssh/config includes managed config"
}

# 8. SSH is strict about config file permissions and silently ignores configs
# with group/world read access.
step_ssh_permissions() {
  header "8/12  SSH permissions"

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

# 9. Remove legacy shell files that conflict with the ZDOTDIR-managed config.
# With ZDOTDIR set, ~/.zshrc is never sourced — it only causes confusion.
# ~/.bashrc and ~/.bash_profile are left alone (may be used by scripts/tools).
step_cleanup_shell() {
  header "9/12  Clean up legacy shell files"

  local -a legacy=("${HOME}/.zshrc" "${HOME}/.zshenv")
  local removed=0

  for f in "${legacy[@]}"; do
    if [[ -L "${f}" ]]; then
      ok "${f} is a symlink — skipping"
      continue
    fi
    if [[ -f "${f}" ]]; then
      info "Removing legacy ${f}"
      run rm "${f}"
      (( removed++ )) || true
    fi
  done

  [[ "${removed}" -eq 0 ]] && ok "No legacy shell files to remove"
}

# 10. Apply sensible macOS defaults for a developer environment.
# All settings are idempotent — safe to re-run. Affected apps are restarted
# at the end to pick up the new values.
step_macos_defaults() {
  header "10/12  macOS defaults"

  # ── Keyboard ──────────────────────────────────────────────────────────────
  # Faster key repeat — essential for vim and terminal work.
  # System default: InitialKeyRepeat=25, KeyRepeat=6
  run defaults write NSGlobalDomain KeyRepeat -int 2
  run defaults write NSGlobalDomain InitialKeyRepeat -int 15
  # Allow key repeat in all apps (disables the press-and-hold accent popup)
  run defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
  # Disable smart quotes, smart dashes, autocorrect — all break code
  run defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  run defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
  run defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
  run defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
  run defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

  # ── Finder ────────────────────────────────────────────────────────────────
  run defaults write com.apple.finder AppleShowAllFiles -bool true
  run defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  run defaults write com.apple.finder ShowPathbar -bool true
  run defaults write com.apple.finder ShowStatusBar -bool true
  # Show full POSIX path in Finder title bar
  run defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
  # Search the current folder by default (not "This Mac")
  run defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
  # Keep folders on top when sorting by name
  run defaults write com.apple.finder _FXSortFoldersFirst -bool true
  # Default to list view
  run defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  # No warning when changing a file extension
  run defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  # Don't write .DS_Store on network or USB volumes
  run defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
  run defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

  # ── Dock ──────────────────────────────────────────────────────────────────
  run defaults write com.apple.dock autohide -bool true
  # Remove the auto-hide show/hide delay
  run defaults write com.apple.dock autohide-delay -float 0
  run defaults write com.apple.dock autohide-time-modifier -float 0.4
  # Don't show recently used apps in Dock
  run defaults write com.apple.dock show-recents -bool false
  # Don't reorder Spaces based on most recent use
  run defaults write com.apple.dock mru-spaces -bool false

  # ── Screenshots ───────────────────────────────────────────────────────────
  run defaults write com.apple.screencapture type -string "png"
  run defaults write com.apple.screencapture disable-shadow -bool true

  # ── Dialogs ───────────────────────────────────────────────────────────────
  # Expand save and print panels by default instead of showing the compact form
  run defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  run defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
  run defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  run defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  # ── Appearance ────────────────────────────────────────────────────────────
  # Accent + highlight are NOT set here. macOS doesn't expose a clean defaults
  # key for the Tahoe Custom Color picker (the hex lives in encoded form), and
  # writing AppleAccentColor would clobber a manually-picked Custom Color on
  # every re-run. Set Custom Color #286983 (dawnfox pine) once via System
  # Settings → Appearance → Accent → Custom Color.

  # ── Security ──────────────────────────────────────────────────────────────
  # Require password immediately after sleep or screensaver begins
  run defaults write com.apple.screensaver askForPassword -int 1
  run defaults write com.apple.screensaver askForPasswordDelay -int 0

  # Restart affected apps to apply changes (no-op if process isn't running)
  run killall Finder 2>/dev/null || true
  run killall Dock 2>/dev/null || true
  run killall SystemUIServer 2>/dev/null || true

  ok "macOS defaults applied"
}

# 11. Reload AeroSpace's config so symlink updates take effect without a
# restart. Accessibility is granted later in step_app_accessibility (12/12),
# consolidated with Sol to avoid two trips through System Settings.
step_aerospace() {
  header "11/12  AeroSpace"

  if [[ ! -d "/Applications/AeroSpace.app" ]]; then
    warn "AeroSpace not installed — skipping"
    return
  fi

  if command_exists aerospace && pgrep -x AeroSpace >/dev/null 2>&1; then
    info "Reloading AeroSpace config"
    run aerospace reload-config || warn "Reload failed — check config syntax"
  else
    info "AeroSpace not running — config will load on next launch"
  fi

  ok "AeroSpace ready"
}

# 12. AeroSpace needs Accessibility for window management. macOS TCC requires
# the user to flip the toggle in System Settings — interactive only.
step_app_accessibility() {
  header "12/12  Application Accessibility"

  local -a apps=()
  [[ -d "/Applications/AeroSpace.app" ]] && apps+=("AeroSpace")

  if (( ${#apps[@]} == 0 )); then
    warn "No apps requiring Accessibility installed — skipping"
    return
  fi

  prompt_for_accessibility "${apps[@]}"
  ok "Accessibility prompts complete"
}

# ── Main ──────────────────────────────────────────────────────────────────────

printf "\n  dotfiles setup\n  %s\n" "${DOTFILES_DIR}"
$DRY_RUN && printf "\n  ${YELLOW}DRY RUN — no changes will be made${RESET}\n"

step_zdotdir
step_homebrew
step_shell
step_symlinks
step_claude
step_git_hooks
step_ssh_include
step_ssh_permissions
step_cleanup_shell
step_macos_defaults
step_aerospace
step_app_accessibility

printf "\n${DIM}── done ──────────────────────────────────────────────${RESET}\n\n"
if ! $DRY_RUN; then
  printf "  ${YELLOW}Manual follow-ups${RESET} (macOS won't let scripts do these silently):\n"
  printf "    • Grant AeroSpace Accessibility → System Settings → Privacy & Security → Accessibility\n"
  printf "    • Set system accent to Pine     → System Settings → Appearance → Custom Color #286983\n\n"
  printf "  Then restart your terminal to apply all changes.\n\n"
fi
