# Niri (Wayland compositor) user config, plus the swww wallpaper helpers it
# spawns at startup. The system-level `programs.niri.enable` lives in
# modules/system/desktop.nix.
{ config, pkgs, osConfig, lib, ... }:

let
  # nixpkgs renamed `swww` -> `awww` (binaries are awww / awww-daemon). waypaper's
  # "swww" backend shells out to a command literally named `swww`, so expose
  # swww / swww-daemon names pointing at awww for compatibility.
  swwwCompat = pkgs.symlinkJoin {
    name = "swww-compat";
    paths = [ pkgs.awww ];
    postBuild = ''
      ln -sf $out/bin/awww $out/bin/swww
      ln -sf $out/bin/awww-daemon $out/bin/swww-daemon
    '';
  };

  # Starts the swww wallpaper daemon, waits until its socket is ready, then
  # asks waypaper to restore the last-selected wallpaper. Spawned by niri.
  swwwInit = pkgs.writeShellScript "swww-init" ''
    export PATH=${swwwCompat}/bin:$PATH
    swww-daemon &
    until swww query >/dev/null 2>&1; do sleep 0.2; done
    ${pkgs.waypaper}/bin/waypaper --restore
  '';
in
{
  home.packages = [ swwwCompat ];

  # Generate the Niri config file.
  xdg.configFile."niri/config.kdl".text = with osConfig.lib.stylix.colors.withHashtag; ''
    // --- Startup ---
    spawn-at-startup "${swwwInit}"
    spawn-at-startup "${pkgs.waybar}/bin/waybar"
    spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"

    prefer-no-csd

    // --- Input ---
    input {
        keyboard {
            repeat-rate 35
            repeat-delay 180
            xkb {
                layout "us"
            }
        }
        focus-follows-mouse max-scroll-amount="0%"
    }

    // --- Layout & Styling ---
    layout {
        gaps 8
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

        focus-ring {
            width 4
            active-color "${base0D}"
            inactive-color "${base02}"
        }

        border {
            off
            width 4
            active-color "${base0E}"
            inactive-color "${base02}"
        }
    }

    // --- Window Rules (Handles Translucency correctly) ---
    window-rule {
        opacity 1.0
    }

output "DP-1" {
        mode "5120x1440@119.99"
        transform "normal"
        position x=0 y=0
    }
    output "DP-2" {
        mode "2560x1440@143.856"
        transform "90"
        position x=5120 y=0
    }
    output "HDMI-A-1" {
        mode "2560x1440@143.856"
        transform "normal"
        position x=6560 y=0
    }

    // --- Keybinds ---
    binds {
        Mod+Shift+Slash { show-hotkey-overlay; }
        Mod+Return { spawn "ghostty"; }
        Mod+Shift+Return { spawn "fuzzel"; }
        Mod+Q repeat=false { close-window; }
        Mod+Shift+E { quit; }

        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }

        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }

        Mod+Ctrl+Left  { focus-monitor-left; }
        Mod+Ctrl+Down  { focus-monitor-down; }

        Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
        Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
        Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
        Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+6 { focus-workspace 6; }
        Mod+7 { focus-workspace 7; }
        Mod+8 { focus-workspace 8; }
        Mod+9 { focus-workspace 9; }

        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }
        Mod+Shift+6 { move-column-to-workspace 6; }
        Mod+Shift+7 { move-column-to-workspace 7; }
        Mod+Shift+8 { move-column-to-workspace 8; }
        Mod+Shift+9 { move-column-to-workspace 9; }

        Mod+Shift+R { switch-preset-window-height; }
        Mod+Ctrl+R { reset-window-height; }
        Mod+F { maximize-column; }
        Mod+Shift+F { fullscreen-window; }
        Mod+Ctrl+F { expand-column-to-available-width; }
        Mod+Shift+P { power-off-monitors; }
        Mod+C { center-column; }
        Mod+Ctrl+C { center-visible-columns; }

        Print { spawn "flameshot" "gui"; }
        Mod+Print { spawn "flameshot" "gui" "--clipboard" "--accept-on-select"; }

        XF86AudioRaiseVolume allow-when-locked=true { spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%"; }
        XF86AudioMute        allow-when-locked=true { spawn "pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle"; }
    }
  '';
}
