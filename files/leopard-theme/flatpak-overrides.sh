#!/bin/sh
# Let Flatpak apps see your Leopard theme and GTK config.
# Not run automatically. Review, then run:  sh ~/.config/leopard-theme/flatpak-overrides.sh
# Undo with: flatpak override --user --reset
#
# Deliberately does NOT set GTK_THEME globally: it breaks libadwaita apps.
# They get the colours and shapes from gtk-4.0/gtk.css instead.

flatpak override --user \
  --filesystem=~/.themes:ro \
  --filesystem=~/.icons:ro \
  --filesystem=xdg-config/gtk-3.0:ro \
  --filesystem=xdg-config/gtk-4.0:ro

# For a GTK3 Flatpak app that still ignores the theme, force it per app, e.g.:
# flatpak override --user --env=GTK_THEME=OS-X-Leopard-1.2 org.example.App
