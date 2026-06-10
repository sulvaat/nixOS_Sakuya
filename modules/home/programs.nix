# Misc user programs: launcher, terminals, git, file manager, shell helpers.
{ config, pkgs, lib, ... }:
{
  programs.fuzzel = {
    enable = true;
    settings = lib.mkForce {
      main = {
        font = "JetBrainsMono Nerd Font:size=14";
        terminal = "${pkgs.ghostty}/bin/ghostty";
        icon-theme = "Papirus-Dark";
        width = 35;
        lines = 10;
        horizontal-pad = 30;
        vertical-pad = 20;
        inner-pad = 10;
        line-height = 30;
        layer = "overlay";
      };
      colors = {
        background = "1a1b26dd";
        text = "c0caf5ff";
        match = "ff9e64ff";
        selection = "7aa2f7ff";
        selection-text = "1a1b26ff";
        selection-match = "ff9e64ff";
        border = "7aa2f7ff";
      };
      border = {
        width = 3;
        radius = 10;
      };
    };
  };

  programs.kitty.enable = true;
  programs.git.enable = true;
  programs.ghostty.enable = true;

  programs.yazi = {
    enable = true;
    enableFishIntegration = true; # Automatically hooks up shell wrappers
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true; # Replaces standard 'cd' smart-tracking hooks
  };

  # OBS (disabled for now)
  #programs.obs-studio = {
  #    enable = true;
  #    plugins = [
  #      pkgs.obs-studio-plugins.distroav
  #    ];
  #};
}
