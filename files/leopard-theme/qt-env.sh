# Make Qt apps (K3b, VLC, ...) use your GTK theme.
# Needs the package qt5-style-plugins (sudo apt install qt5-style-plugins).
# Works for Qt5 only: Qt6 dropped the GTK style. For Qt6 use Kvantum instead.
#
# To enable, add this line to the end of ~/.profile, then log out and back in:
#   . "$HOME/.config/leopard-theme/qt-env.sh"

export QT_QPA_PLATFORMTHEME=gtk2

# LibreOffice: only needed if it looks generic (check Tools > Options > View).
# Needs libreoffice-gtk3.
# export SAL_USE_VCLPLUGIN=gtk3
