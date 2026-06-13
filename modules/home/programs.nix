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

  # Ghostty terminal. These settings were previously hand-edited in
  # ~/.config/ghostty/config, which drifted from this repo. Keep all changes
  # HERE so home-manager owns the file (it writes ~/.config/ghostty/config).
  programs.ghostty = {
    enable = true;
    settings = {
      # --- Window & Layout ---
      # Remove the native titlebar/borders so Niri handles window styling.
      window-decoration = "none";
      # Center text when the window is resized.
      window-padding-balance = true;

      # --- Typography ---
      font-family = "JetBrainsMono Nerd Font";
      font-size = 11;

      # --- Colors & Aesthetics ---
      theme = "catppuccin-macchiato";

      # --- Transparency ---
      # background-opacity = 1 is fully opaque; lower it (e.g. 0.92) to bring
      # back translucency. alpha-blending controls how the blend is computed.
      alpha-blending = "linear-corrected";
      background-opacity = 0.8;
      # Frosted-glass blur behind the window (only visible when opacity < 1).
      background-blur = 50;

      # --- UI Elements ---
      cursor-style = "bar";
      # Hide the mouse cursor while typing.
      mouse-hide-while-typing = true;

      # Send ESC + CR on Shift+Enter.
      keybind = [ "shift+enter=text:\\x1b\\r" ];
    };
  };

  programs.yazi = {
    enable = true;
    enableFishIntegration = true; # Automatically hooks up shell wrappers
    # Keep the legacy wrapper name (the cd-on-quit shell function is `yy`); newer
    # home-manager changed the default to `y`. Pinned to avoid the deprecation
    # warning and a surprise rename.
    shellWrapperName = "yy";
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
