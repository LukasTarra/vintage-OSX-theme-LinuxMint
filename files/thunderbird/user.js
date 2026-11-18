// Read once at Thunderbird startup. Remove these lines to undo.

// Allow chrome/userChrome.css to be loaded
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Draw content-area widgets (scrollbars, form controls) with the GTK theme.
// Name must match the folder in ~/.themes.
user_pref("widget.content.gtk-theme-override", "OS-X-Leopard-1.2");

// Use classic (non-overlay) scrollbars so the theme's scrollbars show
user_pref("widget.gtk.overlay-scrollbars.enabled", false);
