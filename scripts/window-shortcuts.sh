#!/usr/bin/env bash
# window-shortcuts.sh — apply macOS App Shortcuts (NSUserKeyEquivalents)
# declaratively from an INI file.
#
# Usage: window-shortcuts.sh [-n|--dry-run] [ini-file]
#
# Each INI section is a preferences domain (NSGlobalDomain = "All
# Applications"), each key a menu item title, each value a shortcut spec such
# as "ctrl+alt+left". A domain's dictionary is written wholesale, so removing
# an entry removes the binding and hand-made System Settings entries for a
# managed domain are overwritten. Domains dropped from the file are cleaned up
# on the next run via the state file.
set -euo pipefail

INI_DEFAULT="${XDG_CONFIG_HOME:-$HOME/.config}/window-shortcuts/shortcuts.ini"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/window-shortcuts/managed-domains"

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
}

dry_run=0
ini=""

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "window-shortcuts: unknown option: $1" >&2; exit 2 ;;
    *) ini="$1" ;;
  esac
  shift
done

ini="${ini:-$INI_DEFAULT}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "window-shortcuts: macOS only; nothing to do." >&2
  exit 0
fi

if [ ! -f "$ini" ]; then
  echo "window-shortcuts: config not found: $ini" >&2
  exit 1
fi

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# Translate a key name into the character the menu system expects. Multi-byte
# keys come out as \Uxxxx escapes, which `defaults` resolves when it parses
# the value as a property list.
key_char() {
  local name
  name="$(lower "$1")"
  case "$name" in
    left)          printf '\\U2190' ;;
    right)         printf '\\U2192' ;;
    up)            printf '\\U2191' ;;
    down)          printf '\\U2193' ;;
    return)        printf '\\U21A9' ;;
    enter)         printf '\\U2324' ;;
    tab)           printf '\\U21E5' ;;
    escape|esc)    printf '\\U001B' ;;
    space)         printf ' ' ;;
    delete|backspace) printf '\\U232B' ;;
    forwarddelete) printf '\\U2326' ;;
    home)          printf '\\U2196' ;;
    end)           printf '\\U2198' ;;
    pageup)        printf '\\U21DE' ;;
    pagedown)      printf '\\U21DF' ;;
    plus)          printf '+' ;;
    minus)         printf '-' ;;
    equal)         printf '=' ;;
    f[1-9]|f1[0-9]) printf '\\U%04X' "$((0xF704 + ${name#f} - 1))" ;;
    ?)             printf '%s' "$1" ;;
    *)             return 1 ;;
  esac
}

# "ctrl+alt+left" -> "^~\U2190". Modifiers are emitted in the order macOS
# displays them (control, option, shift, command).
encode_shortcut() {
  local rest="$1"
  local token ctrl="" alt="" sft="" cmd="" key="" char
  while [ -n "$rest" ]; do
    case "$rest" in
      *+*) token="${rest%%+*}"; rest="${rest#*+}" ;;
      *)   token="$rest"; rest="" ;;
    esac
    token="$(trim "$token")"
    [ -z "$token" ] && continue
    case "$(lower "$token")" in
      cmd|command)   cmd='@' ;;
      ctrl|control)  ctrl='^' ;;
      alt|opt|option) alt='~' ;;
      shift)         sft='$' ;;
      *)
        if [ -n "$key" ]; then
          echo "window-shortcuts: more than one key in \"$1\"" >&2
          return 1
        fi
        key="$token"
        ;;
    esac
  done

  if [ -z "$key" ]; then
    echo "window-shortcuts: no key in \"$1\"" >&2
    return 1
  fi

  if ! char="$(key_char "$key")"; then
    echo "window-shortcuts: unknown key \"$key\" in \"$1\"" >&2
    return 1
  fi

  printf '%s%s%s%s%s' "$ctrl" "$alt" "$sft" "$cmd" "$char"
}

domain=""
pairs=()
applied_domains=""
errors=0

flush_domain() {
  [ -z "$domain" ] && return 0

  applied_domains="$applied_domains$domain
"

  if [ "${#pairs[@]}" -eq 0 ]; then
    echo "==> $domain: no shortcuts, clearing"
    [ "$dry_run" -eq 1 ] || defaults delete "$domain" NSUserKeyEquivalents 2>/dev/null || true
    return 0
  fi

  echo "==> $domain: $(( ${#pairs[@]} / 2 )) shortcuts"
  if [ "$dry_run" -eq 1 ]; then
    printf '    defaults write %s NSUserKeyEquivalents -dict' "$domain"
    printf ' %q' "${pairs[@]}"
    printf '\n'
  else
    defaults write "$domain" NSUserKeyEquivalents -dict "${pairs[@]}"
  fi
}

while IFS= read -r line || [ -n "$line" ]; do
  line="$(trim "$line")"
  case "$line" in
    ''|'#'*|';'*) continue ;;
    '['*']')
      flush_domain
      domain="${line#[}"
      domain="${domain%]}"
      domain="$(trim "$domain")"
      pairs=()
      continue
      ;;
  esac

  case "$line" in
    *=*) ;;
    *)
      echo "window-shortcuts: ignoring unparsable line: $line" >&2
      errors=1
      continue
      ;;
  esac

  title="$(trim "${line%%=*}")"
  spec="$(trim "${line#*=}")"

  if [ -z "$domain" ]; then
    echo "window-shortcuts: \"$title\" appears before any [domain] section" >&2
    errors=1
    continue
  fi

  if ! value="$(encode_shortcut "$spec")"; then
    errors=1
    continue
  fi

  pairs+=("$title" "$value")
done < "$ini"

flush_domain

# Drop domains that this file used to manage but no longer lists.
if [ -f "$STATE_FILE" ]; then
  while IFS= read -r stale; do
    [ -z "$stale" ] && continue
    case "
$applied_domains" in
      *"
$stale
"*) continue ;;
    esac
    echo "==> $stale: no longer managed, clearing"
    [ "$dry_run" -eq 1 ] || defaults delete "$stale" NSUserKeyEquivalents 2>/dev/null || true
  done < "$STATE_FILE"
fi

if [ "$dry_run" -eq 0 ]; then
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s' "$applied_domains" > "$STATE_FILE"
fi

if [ "$errors" -ne 0 ]; then
  echo "window-shortcuts: finished with errors" >&2
  exit 1
fi

echo "==> Window shortcuts applied — relaunch apps to pick them up"
