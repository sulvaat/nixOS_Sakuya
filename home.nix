# Home Manager entrypoint. Per-app config lives in modules/home/*; this file
# just wires those in plus the user identity.
{ config, pkgs, osConfig, lib, ... }:
{
  imports = [
    ./modules/home/packages.nix
    ./modules/home/input-method.nix
    ./modules/home/niri.nix
    ./modules/home/waybar.nix
    ./modules/home/services.nix
    ./modules/home/theming.nix
    ./modules/home/shells.nix
    ./modules/home/programs.nix
  ];

  home.username = "sul";
  home.homeDirectory = "/home/sul";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;
}
