#!/usr/bin/env bash
# nvim-open-plist.sh — patches NvimOpen.app's Info.plist after osacompile.
# Usage: nvim-open-plist.sh <path-to-NvimOpen.app>
set -euo pipefail

APP="${1:?Usage: $0 <path-to-NvimOpen.app>}"
PLIST="$APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy

# Helper: set key if it exists, otherwise add it
pb_set_or_add() {
  local type="$1" key="$2" value="$3"
  "$PB" -c "Set $key $value" "$PLIST" 2>/dev/null \
    || "$PB" -c "Add $key $type $value" "$PLIST"
}

# ── Identity ────────────────────────────────────────────────────────────────
pb_set_or_add string ":CFBundleIdentifier"        "com.larsbackman.nvimopen"
pb_set_or_add string ":CFBundleName"              "NvimOpen"
pb_set_or_add string ":CFBundleVersion"           "1.0.0"
pb_set_or_add string ":CFBundleShortVersionString" "1.0.0"

# ── Hide from Dock / menu bar (LSUIElement) ──────────────────────────────────
pb_set_or_add bool ":LSUIElement" "true"

# ── Document types (file handler registration) ───────────────────────────────
"$PB" -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :CFBundleDocumentTypes array" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"

UTIS=(
  public.plain-text
  public.comma-separated-values-text
  public.json
  public.xml
  public.shell-script
  public.log
  public.source-code
  public.python-script
  public.ruby-script
  public.swift-source
  net.daringfireball.markdown
)

i=0
for uti in "${UTIS[@]}"; do
  "$PB" -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:$i string $uti" "$PLIST"
  i=$((i + 1))
done

# ── Alternate document types (appear in "Open With", not default) ────────────
# web types: NvimOpen shows as an option but won't claim the browser role
"$PB" -c "Add :CFBundleDocumentTypes:1 dict" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:1:CFBundleTypeRole string Editor" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:1:LSHandlerRank string Alternate" "$PLIST"
"$PB" -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes array" "$PLIST"

ALT_UTIS=(
  public.html
  public.css
)

i=0
for uti in "${ALT_UTIS[@]}"; do
  "$PB" -c "Add :CFBundleDocumentTypes:1:LSItemContentTypes:$i string $uti" "$PLIST"
  i=$((i + 1))
done

echo "Info.plist patched: $(basename "$APP")"
