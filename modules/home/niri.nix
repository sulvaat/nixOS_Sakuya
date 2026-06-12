# Niri (Wayland compositor) user config, plus the swww wallpaper helpers it
# spawns at startup. The system-level `programs.niri.enable` lives in
# modules/system/desktop.nix.
#
# The KDL config now lives in ./niri/config.kdl.tmpl as tool-editable data
# (edited by the `nirinator` TUI). Stylix colors are `@baseXX@` tokens and the
# dynamic store paths are `@swww_init@` / `@waybar_init@` / `@xwayland_satellite@`;
# both are substituted below at build time, so the rendered output is unchanged.
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

  # Boot race: niri spawns waybar while systemd brings up the swaync service
  # concurrently. If waybar's custom/swaync subscriber (swaync-client -swb)
  # connects before the daemon's D-Bus interface is ready, it emits nothing and
  # never recovers, so the notification bell is missing from the clock pill
  # until waybar is restarted. Wait (bounded to ~10s) for the daemon to answer
  # before launching waybar. See modules/home/services.nix and waybar.nix.
  waybarInit = pkgs.writeShellScript "waybar-init" ''
    for i in $(seq 1 50); do
      ${pkgs.swaynotificationcenter}/bin/swaync-client --count >/dev/null 2>&1 && break
      sleep 0.2
    done
    exec ${pkgs.waybar}/bin/waybar
  '';

  colors = osConfig.lib.stylix.colors.withHashtag;
  slots = [
    "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
    "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F"
  ];
  palette = builtins.listToAttrs (map (n: { name = n; value = colors.${n}; }) slots);

  # Tokens used in the template -> their concrete values at build time.
  tokens = (map (n: "@${n}@") slots) ++ [ "@swww_init@" "@waybar_init@" "@xwayland_satellite@" ];
  values = (map (n: colors.${n}) slots) ++ [
    "${swwwInit}"
    "${waybarInit}"
    "${pkgs.xwayland-satellite}"
  ];
  render = builtins.replaceStrings tokens values;
in
{
  home.packages = [ swwwCompat ];

  # Generate the Niri config from the tool-editable template.
  xdg.configFile."niri/config.kdl".text = render (builtins.readFile ./niri/config.kdl.tmpl);

  # Expose the live Stylix palette to nirinator so it can render `@baseXX@`
  # tokens with correct hex when validating with `niri validate`.
  xdg.configFile."nirinator/palette.json".text = builtins.toJSON palette;
}
