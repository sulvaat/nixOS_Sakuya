# System entrypoint. Most settings live in modules/system/*; this file just
# wires those in plus a few global bits (Home Manager, locale, nix, state).
# Help: configuration.nix(5) man page, https://search.nixos.org/options, nixos-help.
{ config, lib, pkgs, ... }:
{
  imports = [
    # Results of the hardware scan.
    ./hardware-configuration.nix

    # System modules
    ./modules/system/boot.nix
    ./modules/system/hardware.nix
    ./modules/system/networking.nix
    ./modules/system/audio.nix
    ./modules/system/desktop.nix
    ./modules/system/stylix.nix
    ./modules/system/virtualisation.nix
    ./modules/system/filesystems.nix
    ./modules/system/programs.nix
    ./modules/system/packages.nix
    ./modules/system/users.nix
  ];

  # Home Manager
  home-manager.useUserPackages = true;
  home-manager.useGlobalPkgs = true;
  home-manager.backupFileExtension = "backup";
  home-manager.users.sul = {
    imports = [ ./home.nix ];
  };

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # Clean up garbage every week.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # The first version of NixOS installed on this machine. Most users should
  # NEVER change this after install. See `man configuration.nix` or
  # https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?
}
