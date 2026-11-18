#!/usr/bin/env bash
# Run this on the machine where the theme already looks right. It packs the
# exact theme/icon folders into ./assets so install.sh can rebuild them offline
# (no dependence on GitHub repos that may change or vanish).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/config.env"
mkdir -p "$HERE/assets"

pack() {  # pack SRC_DIR NAME
  if [ -d "$1" ]; then
    # Archive the folder under its own name; install.sh renames it on install.
    tar -C "$(dirname "$1")" -czf "$HERE/assets/$2.tar.gz" "$(basename "$1")"
    echo "packed $1 -> assets/$2.tar.gz"
  else
    echo "skip: $1 not found" >&2
  fi
}

# If you already applied gtk3-popup-fix.py, the snapshot contains the patched
# file; that's fine, the patch is idempotent.
pack "$HOME/.themes/$GTK_THEME"             OS-X-Leopard
pack "$HOME/.icons/$ICON_THEME"             Mac-OS-X-Lion
pack "$HOME/.icons/Mac-OS-X-Cheetah-master" Mac-OS-X-Cheetah

mkdir -p "$HERE/assets/fonts"
for f in "$HOME"/.fonts/*; do [ -f "$f" ] && cp -n "$f" "$HERE/assets/fonts/"; done
echo "copied fonts from ~/.fonts"
echo "Done. Commit the assets/ folder (check each theme's licence before publishing it)."
