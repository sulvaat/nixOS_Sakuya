# Stylix: system-wide theme, wallpaper, and fonts.
{ config, lib, pkgs, ... }:
{
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-city-dark.yaml";
  # Path is relative to this file; ../../ points back at /etc/nixos.
  stylix.image = ../../pano.jpg;
  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };
  };
}
