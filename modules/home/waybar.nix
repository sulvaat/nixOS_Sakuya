# Waybar status bar, plus the helper script that lists windows in the focused
# Niri workspace.
{ config, pkgs, osConfig, lib, ... }:

let
  # Lists the titles of every window in the currently-focused niri workspace,
  # emitted as a single space-separated line for the waybar custom module.
  niriWindows = pkgs.writeShellScript "waybar-niri-windows" ''
    ws=$(${pkgs.niri}/bin/niri msg --json workspaces \
      | ${pkgs.jq}/bin/jq '[.[] | select(.is_focused)][0].id')
    [ -z "$ws" ] && exit 0
    [ "$ws" = "null" ] && exit 0
    ${pkgs.niri}/bin/niri msg --json windows \
      | ${pkgs.jq}/bin/jq -r --argjson ws "$ws" '
          [ .[] | select(.workspace_id == $ws) | (.title // .app_id // "window") ]
          | map(if (. | length) > 28 then (.[0:27] + "…") else . end)
          | join("   ")
        '
  '';
in
{
  programs.waybar = {
    enable = true;
    # Launched by niri's spawn-at-startup, so no systemd service (avoids a
    # duplicate stacked bar).
    systemd.enable = false;

    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 6;
        margin-top = 6;
        margin-left = 12;
        margin-right = 12;

        modules-left = [ "niri/workspaces" "custom/windows" ];
        modules-center = [ "clock" ];
        modules-right = [ "pulseaudio" "memory" "cpu" "disk" "tray" ];

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };

        "custom/windows" = {
          exec = "${niriWindows}";
          interval = 1;
          format = "  {}";
          max-length = 90;
          tooltip = false;
        };

        clock = {
          format = "  {:%a %d %b   %H:%M}";
          tooltip-format = "<tt><big>{calendar}</big></tt>";
        };

        pulseaudio = {
          format = "{icon}  {volume}%";
          format-bluetooth = "  {volume}%";
          format-muted = "  muted";
          format-icons = {
            default = [ "" "" "" ];
          };
          scroll-step = 5;
          on-click = "pavucontrol";
        };

        memory = {
          interval = 5;
          format = "  {}%";
        };

        cpu = {
          interval = 5;
          format = "  {usage}%";
        };

        disk = {
          interval = 30;
          format = "  {percentage_used}%";
          path = "/";
        };

        tray = {
          icon-size = 18;
          spacing = 8;
        };
      };
    };

    style = with osConfig.lib.stylix.colors.withHashtag; lib.mkForce ''
      * {
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono";
        font-size: 14px;
        min-height: 0;
      }

      /* Transparent bar so each module reads as a floating pill */
      window#waybar {
        background: transparent;
      }

      /* Shared pill style */
      #workspaces,
      #custom-windows,
      #clock,
      #pulseaudio,
      #memory,
      #cpu,
      #disk,
      #tray {
        background: ${base00};
        color: ${base05};
        padding: 2px 14px;
        margin: 4px 4px;
        border-radius: 14px;
      }

      /* Workspaces: pill wrapper with inner buttons */
      #workspaces {
        padding: 2px 6px;
      }
      #workspaces button {
        padding: 0 6px;
        margin: 2px 1px;
        color: ${base04};
        background: transparent;
        border-radius: 10px;
      }
      #workspaces button.active,
      #workspaces button.focused {
        color: ${base00};
        background: ${base0D};
      }
      #workspaces button:hover {
        background: ${base02};
        color: ${base07};
        box-shadow: inherit;
        text-shadow: inherit;
      }

      /* Accent colors per module */
      #custom-windows { color: ${base0C}; }
      #clock          { color: ${base0A}; font-weight: bold; }
      #pulseaudio     { color: ${base0D}; }
      #memory         { color: ${base0B}; }
      #cpu            { color: ${base0E}; }
      #disk           { color: ${base09}; }
      #tray           { color: ${base05}; }
    '';
  };
}
