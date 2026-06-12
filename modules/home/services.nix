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

  # Notification daemon + center (Wayland). SwayNC replaces mako: it gives a
  # themed pill-style popup, per-urgency auto-timeouts, and a slide-out
  # notification center (history drawer) toggled from the far-right waybar bell
  # module (modules/home/waybar). Colors pull from the Tokyo City palette so it
  # matches waybar / niri. Popups follow the focused output (not pinned).
  services.swaync = with osConfig.lib.stylix.colors.withHashtag; {
    enable = true;
    settings = {
      # Popups (toasts) slide down from the top-center, matching the centered
      # bell and drawer.
      positionX = "center";
      positionY = "top";
      # The control center (history drawer) is centered and slides down from the
      # top — matching the now-centered waybar bell.
      control-center-positionX = "center";
      control-center-positionY = "top";
      # Nudge the drawer down a touch so it clears the bar instead of hugging
      # the very top edge of the screen.
      control-center-margin-top = 8;
      layer = "overlay";
      control-center-layer = "top";
      cssPriority = "user";
      timeout = 8;          # normal notifications auto-dismiss after 8s
      timeout-low = 5;
      timeout-critical = 0; # critical stays until dismissed
      fit-to-screen = true;
      control-center-width = 420;
      notification-window-width = 400;
      notification-icon-size = 48;
      notification-body-image-height = 120;
      notification-body-image-width = 220;
      widgets = [ "title" "dnd" "notifications" ];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear all";
        };
        dnd = { text = "Do not disturb"; };
      };
    };

    # GTK CSS, mirroring the floating-pill look: rounded cards, base16 colors,
    # accent border, JetBrainsMono. mkForce so it wins over any Stylix target.
    style = lib.mkForce ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono";
        font-size: 13px;
      }

      /* Popup + center cards: rounded pill-ish cards with an accent border */
      .notification-row { outline: none; }
      .notification {
        border-radius: 14px;
        margin: 6px 10px;
        box-shadow: none;
      }
      .notification-background .notification {
        background: ${base00};
        border: 2px solid ${base0D};
        padding: 4px;
      }
      .notification-background .notification.critical {
        border-color: ${base08};
      }
      .notification-content { padding: 8px; border-radius: 12px; }
      .summary { color: ${base05}; font-weight: bold; }
      .time    { color: ${base04}; }
      .body    { color: ${base04}; }
      .close-button {
        background: ${base08};
        color: ${base00};
        border-radius: 10px;
        margin: 6px;
        padding: 2px 6px;
      }
      .close-button:hover { background: ${base09}; }

      /* The drawer (control center) */
      .control-center {
        background: ${base00};
        border: 2px solid ${base02};
        border-radius: 18px;
        margin: 10px;
        padding: 12px;
      }
      .control-center .notification-background .notification {
        background: ${base01};
        border: 1px solid ${base02};
      }
      .widget-title {
        color: ${base05};
        font-size: 15px;
        font-weight: bold;
        margin: 4px 6px 10px 6px;
      }
      .widget-title > button {
        background: ${base02};
        color: ${base05};
        border-radius: 12px;
        padding: 4px 12px;
        border: none;
      }
      .widget-title > button:hover { background: ${base0D}; color: ${base00}; }
      .widget-dnd { color: ${base05}; margin: 6px; font-size: 14px; }
      .widget-dnd > switch {
        background: ${base02};
        border-radius: 12px;
        border: none;
      }
      .widget-dnd > switch:checked { background: ${base0E}; }
      .widget-dnd > switch slider { background: ${base05}; border-radius: 10px; }
    '';
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
