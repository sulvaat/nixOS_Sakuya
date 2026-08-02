# GTK theming (icons, cursor, dark preference).
{ config, pkgs, lib, ... }:
{
  gtk = {
    enable = true;
    # `tokyonight-gtk-theme` was removed from nixpkgs (its GTK2
    # `gtk-engine-murrine` dependency is gone) and Stylix doesn't theme GTK
    # here, so GTK3 apps use adw-gtk3-dark — a maintained theme that matches
    # modern libadwaita/Adwaita styling (GTK4 apps follow prefer-dark natively,
    # so no gtk4.theme is set). Dark is enforced by the prefer-dark hints and
    # the dconf color-scheme below.
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
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
  };

  # Advertise a dark color-scheme through the freedesktop appearance portal
  # (served by xdg-desktop-portal-gtk). This is what Electron/Chromium, Qt6 and
  # libadwaita apps query to decide dark vs light — gtk-application-prefer-dark
  # alone doesn't reach them. Merges into the interface block the gtk module
  # already populates.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
}
