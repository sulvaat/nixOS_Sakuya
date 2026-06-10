# System-level program/platform enablement.
{ config, lib, pkgs, ... }:
{
  # Fish as a login shell. User config lives in modules/home/shells.nix.
  programs.fish.enable = true;

  # Enable ADB and Fastboot
  #programs.adb.enable = true;

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
  };

  # AppImage support
  programs.appimage.enable = true;
  programs.appimage.binfmt = true; # Helps with file association

  # Flatpak
  services.flatpak.enable = true;
}
