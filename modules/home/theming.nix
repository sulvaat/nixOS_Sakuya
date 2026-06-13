# GTK theming (icons, cursor, dark preference).
{ config, pkgs, lib, ... }:
{
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    # Newer home-manager defaults gtk4.theme to null; keep applying the same
    # theme as GTK2/3 so GTK4 apps stay on Tokyonight-Dark (preserves current
    # behavior and silences the deprecation warning).
    gtk4.theme = config.gtk.theme;
  };

  # Advertise a dark color-scheme through the freedesktop appearance portal
  # (served by xdg-desktop-portal-gtk). This is what Electron/Chromium, Qt6 and
  # libadwaita apps query to decide dark vs light — gtk-application-prefer-dark
  # alone doesn't reach them. Merges into the interface block the gtk module
  # already populates.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
