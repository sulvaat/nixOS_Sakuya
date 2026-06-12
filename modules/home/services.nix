# User services: screenshots, notifications, idle, KDE Connect.
{ config, pkgs, lib, osConfig, ... }:
{
  # Screenshot tool
  services.flameshot = {
    enable = true;
    settings = {
      General = {
        # Critical for Wayland support
        useGrimAdapter = true;
        disabledGrimWarning = true;
        showStartupLaunchMessage = false;
        # Default directory for saved screenshots
        savePath = "${config.home.homeDirectory}/Pictures/Screenshots";
        # Always save to savePath instead of remembering the last-used folder
        savePathFixed = true;
      };
    };
  };

  # Notification daemon (Wayland). Pinned to the main 32:9 Samsung (DP-1, far left).
  # Colors are set explicitly because mako otherwise falls back to its built-in
  # defaults (a steel-blue #285577 background / #4C7899 border) — that was the
  # "blue tint" on notifications. These pull from the Tokyo City palette so mako
  # matches waybar / niri. Drop the alpha (e.g. base00 -> "${base00}e6") if you
  # want translucent notifications; "${base0D}" border matches the focus ring.
  services.mako = with osConfig.lib.stylix.colors.withHashtag; {
    enable = true;
    settings = {
      output = "DP-1";
      anchor = "top-right";
      background-color = "${base00}";
      text-color = "${base05}";
      border-color = "${base0D}";
      border-size = 2;
      border-radius = 8;
    };
  };

  # Screen timeout
  services.swayidle = {
    enable = true;
    timeouts = [
      # After 10 minutes (600 seconds), turn off the displays entirely
      {
        timeout = 600;
        command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
        resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
      }
    ];
    # Empty out the events block so sleep/suspend actions don't try to trigger a locker
    events = [];
  };

  # KDE Connect
  services.kdeconnect = {
    enable = true;
    indicator = true; # Adds the status icon
  };
}
