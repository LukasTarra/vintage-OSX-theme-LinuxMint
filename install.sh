#!/usr/bin/env bash
# Reproduce the Snow Leopard-style desktop on a fresh Linux Mint (Cinnamon).
# Safe to re-run. Anything it replaces is first copied to
# ~/.local/share/leopard-setup/backup-<timestamp>/.
#
#   ./install.sh                 everything
#   ./install.sh --no-apt        skip package installation (no sudo needed)
#   ./install.sh --no-settings   skip gsettings / applet changes
#   ./install.sh --only STEP     one of: apt assets patches gtk4 qt flatpak thunderbird settings
#   ./install.sh --check         just report what is installed/configured
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.env
source "$HERE/config.env"

BACKUP_DIR="$HOME/.local/share/leopard-setup/backup-$(date +%Y%m%d-%H%M%S)"
STEPS=(apt assets patches gtk4 qt flatpak thunderbird settings)
ONLY=""; SKIP=""; CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --no-apt) SKIP+=" apt" ;;
    --no-settings) SKIP+=" settings" ;;
    --only) ONLY="${2:?--only needs a step name}"; shift ;;
    --check) CHECK=1 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
want() { [ -z "$ONLY" ] && [[ " $SKIP " != *" $1 "* ]] || [ "$ONLY" = "$1" ]; }

backup() {  # backup FILE  -> copy an existing file aside before we replace it
  local f="$1"
  [ -e "$f" ] || return 0
  mkdir -p "$BACKUP_DIR$(dirname "$f")"
  cp -a "$f" "$BACKUP_DIR$f"
}

install_file() {  # install_file SRC DEST  (replaces @HOME@ with $HOME)
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && ! diff -q <(sed "s#@HOME@#$HOME#g" "$src") "$dest" >/dev/null 2>&1; then
    backup "$dest"
  fi
  sed "s#@HOME@#$HOME#g" "$src" > "$dest"
  echo "  wrote $dest"
}

# ---------------------------------------------------------------- check
if [ "$CHECK" = 1 ]; then
  for p in "$HOME/.themes/$GTK_THEME" "$HOME/.icons/$ICON_THEME" \
           "$HOME/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/settings.ini" \
           "$HOME/.config/leopard-theme/qt-env.sh"; do
    [ -e "$p" ] && echo "ok       $p" || echo "MISSING  $p"
  done
  if command -v gsettings >/dev/null; then
    for k in "org.cinnamon.desktop.interface gtk-theme" "org.cinnamon.desktop.interface icon-theme" \
             "org.cinnamon.desktop.interface cursor-theme" "org.cinnamon.desktop.wm.preferences theme" \
             "org.cinnamon.desktop.wm.preferences button-layout" "org.cinnamon.theme name"; do
      printf '%-55s %s\n' "$k" "$(gsettings get $k 2>&1)"
    done
  fi
  exit 0
fi

# ------------------------------------------------------------------ apt
step_apt() {
  log "Installing packages (sudo)"
  sudo apt-get update
  # Install one by one so a package missing on your Mint release doesn't abort the rest.
  for p in $APT_PACKAGES; do
    sudo apt-get install -y "$p" || warn "package '$p' could not be installed (skipping)"
  done
}

# --------------------------------------------------------------- assets
# unpack_asset NAME DEST_PARENT FINAL_DIRNAME URL
#   NAME: file stem in ./assets (NAME.tar.gz or NAME.zip). The archive must contain
#   one top-level folder, which is renamed to FINAL_DIRNAME.
unpack_asset() {
  local name="$1" parent="$2" final="$3" url="${4:-}" tmp archive=""
  mkdir -p "$parent"
  if   [ -f "$HERE/assets/$name.tar.gz" ]; then archive="$HERE/assets/$name.tar.gz"
  elif [ -f "$HERE/assets/$name.zip" ];    then archive="$HERE/assets/$name.zip"
  elif [ -n "$url" ]; then
    tmp="$(mktemp -d)"; archive="$tmp/$name.zip"
    log "Downloading $name"
    curl -fL --retry 3 -o "$archive" "$url" || { warn "download of $name failed"; return 0; }
  else
    warn "$name: no archive in assets/ and no URL configured. Run ./snapshot-assets.sh on your current machine, or set the URL in config.env."
    return 0
  fi
  local work; work="$(mktemp -d)"
  case "$archive" in
    *.zip)    unzip -q "$archive" -d "$work" ;;
    *.tar.gz) tar -xzf "$archive" -C "$work" ;;
  esac
  local top; top="$(find "$work" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  [ -n "$top" ] || { warn "$name: archive is empty"; return 0; }
  if [ -e "$parent/$final" ]; then
    backup_dir="$BACKUP_DIR$parent"; mkdir -p "$backup_dir"
    mv "$parent/$final" "$backup_dir/$final"
  fi
  mv "$top" "$parent/$final"
  echo "  installed $parent/$final"
}

step_assets() {
  log "Installing themes and icons"
  unpack_asset OS-X-Leopard  "$HOME/.themes" "$GTK_THEME"            "$LEOPARD_URL"
  unpack_asset Mac-OS-X-Lion "$HOME/.icons"  "$ICON_THEME"           "$LION_URL"
  unpack_asset Mac-OS-X-Cheetah "$HOME/.icons" "Mac-OS-X-Cheetah-master" "$CHEETAH_URL"
  # Fonts: Lato/Inter come from apt (fonts-lato, fonts-inter). Anything in assets/fonts is copied too.
  if [ -d "$HERE/assets/fonts" ]; then
    mkdir -p "$HOME/.fonts"; cp -n "$HERE"/assets/fonts/* "$HOME/.fonts/" 2>/dev/null || true
    fc-cache -f >/dev/null 2>&1 || true
  fi
  gtk-update-icon-cache -f "$HOME/.icons/$ICON_THEME" >/dev/null 2>&1 || true
}

# -------------------------------------------------------------- patches
step_patches() {
  log "Patching the Leopard GTK3 theme (popup/dropdown menus)"
  local css="$HOME/.themes/$GTK_THEME/gtk-3.20/gtk.css"
  if [ -f "$css" ]; then
    [ -e "$css.orig" ] || cp -a "$css" "$css.orig"
    python3 "$HERE/files/patches/gtk3-popup-fix.py" "$css"
  else
    warn "$css not found; run the 'assets' step first"
  fi
}

# ----------------------------------------------------------------- gtk4
step_gtk4() {
  log "GTK4 / libadwaita overrides"
  install_file "$HERE/files/gtk-4.0/gtk.css"      "$HOME/.config/gtk-4.0/gtk.css"
  install_file "$HERE/files/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
}

# ------------------------------------------------------------------- qt
step_qt() {
  log "Qt apps follow the GTK theme"
  install_file "$HERE/files/leopard-theme/qt-env.sh" "$HOME/.config/leopard-theme/qt-env.sh"
  local line='. "$HOME/.config/leopard-theme/qt-env.sh"'
  touch "$HOME/.profile"
  if ! grep -qF "$line" "$HOME/.profile"; then
    backup "$HOME/.profile"
    printf '\n# Leopard theme: Qt follows GTK\n%s\n' "$line" >> "$HOME/.profile"
    echo "  appended to ~/.profile (takes effect after next login)"
  fi
}

# -------------------------------------------------------------- flatpak
step_flatpak() {
  if command -v flatpak >/dev/null; then
    log "Flatpak overrides"
    install_file "$HERE/files/leopard-theme/flatpak-overrides.sh" "$HOME/.config/leopard-theme/flatpak-overrides.sh"
    sh "$HOME/.config/leopard-theme/flatpak-overrides.sh"
  else
    echo "  flatpak not installed, skipping"
  fi
}

# --------------------------------------------------------- thunderbird
step_thunderbird() {
  local root="$HOME/.thunderbird"
  [ -f "$root/profiles.ini" ] || { echo "  no Thunderbird profile yet (start Thunderbird once, then re-run: ./install.sh --only thunderbird)"; return 0; }
  pgrep -x thunderbird >/dev/null && warn "Thunderbird is running; restart it afterwards"
  log "Thunderbird theme"
  # Profile(s) = the install's default profile; fall back to every profile.
  mapfile -t profiles < <(python3 - "$root" <<'PY'
import configparser, os, sys
root = sys.argv[1]
c = configparser.ConfigParser(); c.optionxform = str
c.read(os.path.join(root, "profiles.ini"))
paths = [c[s]["Default"] for s in c.sections() if s.startswith("Install") and "Default" in c[s]]
if not paths:
    paths = [c[s]["Path"] for s in c.sections() if s.startswith("Profile") and "Path" in c[s]]
for p in dict.fromkeys(paths):
    print(p if os.path.isabs(p) else os.path.join(root, p))
PY
)
  for prof in "${profiles[@]}"; do
    [ -d "$prof" ] || continue
    install_file "$HERE/files/thunderbird/userChrome.css" "$prof/chrome/userChrome.css"
    # user.js may hold the user's own prefs: manage only our marked block.
    local uj="$prof/user.js" begin="// >>> leopard-setup" end="// <<< leopard-setup"
    [ -e "$uj" ] && backup "$uj"
    touch "$uj"
    sed -i "\#^$begin#,\#^$end#d" "$uj"
    { echo "$begin"; cat "$HERE/files/thunderbird/user.js"; echo "$end"; } >> "$uj"
    sed -i "s#\"OS-X-Leopard-1.2\"#\"$GTK_THEME\"#" "$uj"
    echo "  configured $prof"
  done
}

# ------------------------------------------------------------- settings
gset() {  # gset SCHEMA KEY VALUE  (VALUE in GVariant text form)
  if gsettings writable "$1" "$2" >/dev/null 2>&1; then
    gsettings set "$1" "$2" "$3" && echo "  $1 $2 = $3"
  else
    warn "cannot set $1 $2 (not in a Cinnamon session?)"
  fi
}

step_settings() {
  command -v gsettings >/dev/null || { warn "gsettings not found"; return 0; }
  log "Cinnamon settings"
  gset org.cinnamon.desktop.interface gtk-theme  "'$GTK_THEME'"
  gset org.cinnamon.desktop.interface icon-theme "'$ICON_THEME'"
  gset org.cinnamon.desktop.wm.preferences theme "'$WM_THEME'"
  gset org.cinnamon.desktop.wm.preferences button-layout "'$BUTTON_LAYOUT'"
  gset org.cinnamon.theme name "'$CINNAMON_THEME'"
  [ -n "$CURSOR_THEME" ] && gset org.cinnamon.desktop.interface cursor-theme "'$CURSOR_THEME'"
  if [ -n "$WALLPAPER" ] && [ -f "$WALLPAPER" ]; then
    gset org.cinnamon.desktop.background picture-uri "'file://$WALLPAPER'"
    gset org.cinnamon.desktop.background picture-options "'zoom'"
  fi
  # Clock: Cinnamon keeps applet options in per-instance JSON files.
  local d="$HOME/.config/cinnamon/spices/calendar@cinnamon.org" f
  if [ -d "$d" ]; then
    for f in "$d"/*.json; do
      [ -f "$f" ] || continue
      backup "$f"
      python3 - "$f" "$CLOCK_FORMAT" <<'PY'
import json, sys
p, fmt = sys.argv[1:3]
d = json.load(open(p))
d["use-custom-format"]["value"] = True
d["custom-format"]["value"] = fmt
json.dump(d, open(p, "w"), indent=4)
PY
      echo "  clock format set in $f"
    done
  else
    echo "  calendar applet not configured yet (add the clock applet, log in once, re-run --only settings)"
  fi
}

# ----------------------------------------------------------------- run
for s in "${STEPS[@]}"; do
  want "$s" && "step_$s"
done
log "Done. Backups (if any): $BACKUP_DIR"
echo "Log out and back in so Qt, Flatpak and the shell pick everything up."
