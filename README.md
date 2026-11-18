# Snow Leopard look for Linux Mint (Cinnamon)

Rebuilds the desktop theming on a fresh Mint install with one command.

```
./snapshot-assets.sh     # once, on the machine that already looks right (packs themes/icons/fonts into assets/)
./install.sh             # on the new machine (asks for sudo for apt)
./install.sh --check     # report what is installed / configured
```

Re-running is safe. Replaced files are backed up to `~/.local/share/leopard-setup/backup-<time>/`.
Run it inside the graphical session (gsettings needs it), then log out and back in.

## What it does

| Step | Effect |
|---|---|
| apt | Murrine/pixbuf GTK2 engines (the Leopard theme needs them), `qt5-style-plugins`, Lato/Inter fonts, DMZ cursors |
| assets | Installs the OS X Leopard GTK/WM theme to `~/.themes`, the Lion and Cheetah icon sets to `~/.icons` (from `assets/` if present, otherwise downloaded) |
| patches | `files/patches/gtk3-popup-fix.py`: best-effort fix for dropdowns opening as a sliver |
| gtk4 | `~/.config/gtk-4.0/gtk.css` + `settings.ini`: Leopard colours, Aqua buttons, window buttons on the left, checkboxes, scrollbars, etc. for libadwaita apps |
| qt | `~/.config/leopard-theme/qt-env.sh`, sourced from `~/.profile` (Qt5 apps follow GTK) |
| flatpak | Lets Flatpak apps see the theme (skipped if Flatpak isn't installed) |
| thunderbird | `userChrome.css` + a marked block in `user.js` for the active profile |
| settings | gsettings: GTK/WM/icon theme, button layout, Cinnamon shell theme (kept at Mint-X-Aqua), optional cursor/wallpaper; clock format in the calendar applet |

Settings live in `config.env`.

## Not covered

* The Mint menu icon, panel layout, applet choices and hot corners: Cinnamon stores them per instance. Export them with `dconf dump /org/cinnamon/ > cinnamon.dconf` and restore with `dconf load /org/cinnamon/ < cinnamon.dconf`.
* The Leopard Cinnamon shell theme (buggy, so unused), the iOS-X theme, XCursor-Pro, the wallpaper.
* `LION_URL` has no verified upstream; use `snapshot-assets.sh`. The Leopard/Cheetah GitHub URLs in `config.env` were not test-downloaded.
* Check each theme's licence before publishing `assets/` anywhere.
