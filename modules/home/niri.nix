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

  # When a game (e.g. Halo Infinite under gamescope) takes exclusive fullscreen,
  # niri drops its layer-shell surfaces (waybar, the swww wallpaper) and does not
  # always re-show them on exit. The processes survive, so a full niri restart is
  # overkill — this respawns waybar and repaints the wallpaper. Bound to a key
  # below so recovery is one chord instead of a compositor restart.
  niriRestore = pkgs.writeShellScript "niri-restore-shell" ''
    ${pkgs.procps}/bin/pkill -x waybar 2>/dev/null || true
    export PATH=${swwwCompat}/bin:$PATH
    ${pkgs.waypaper}/bin/waypaper --restore >/dev/null 2>&1 &
    exec ${waybarInit}
  '';

  # Screenshots on niri via grim + slurp + satty (flameshot v14's portal-only
  # capture never worked reliably here). slurp selects a region, grim captures
  # it, satty is the annotation editor (arrows/boxes/text/blur, save + copy).
  # Escaping slurp (empty selection) exits cleanly instead of erroring grim.
  screenshotAnnotate = pkgs.writeShellScript "niri-screenshot" ''
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    geom=$(${pkgs.slurp}/bin/slurp) || exit 0
    [ -z "$geom" ] && exit 0
    ${pkgs.grim}/bin/grim -g "$geom" - | ${pkgs.satty}/bin/satty --filename - \
      --output-filename "$dir/screenshot-$(date +%Y%m%d-%H%M%S).png" \
      --copy-command ${pkgs.wl-clipboard}/bin/wl-copy --early-exit
  '';

  # Quick region grab straight to the clipboard, no editor (matches the old
  # flameshot --clipboard --accept-on-select binding).
  screenshotClip = pkgs.writeShellScript "niri-screenshot-clip" ''
    geom=$(${pkgs.slurp}/bin/slurp) || exit 0
    [ -z "$geom" ] && exit 0
    ${pkgs.grim}/bin/grim -g "$geom" - | ${pkgs.wl-clipboard}/bin/wl-copy
  '';

  colors = osConfig.lib.stylix.colors.withHashtag;
  slots = [
    "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
    "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F"
  ];
  palette = builtins.listToAttrs (map (n: { name = n; value = colors.${n}; }) slots);

  # Tokens used in the template -> their concrete values at build time.
  tokens = (map (n: "@${n}@") slots) ++ [ "@swww_init@" "@waybar_init@" "@niri_restore@" "@screenshot@" "@screenshot_clip@" "@xwayland_satellite@" "@fcitx5@" ];
  values = (map (n: colors.${n}) slots) ++ [
    "${swwwInit}"
    "${waybarInit}"
    "${niriRestore}"
    "${screenshotAnnotate}"
    "${screenshotClip}"
    "${pkgs.xwayland-satellite}"
    # The wrapped fcitx5 (bundles the Mozc addon) from the system input-method
    # module, so the daemon finds its engines.
    "${osConfig.i18n.inputMethod.package}/bin/fcitx5"
  ];
  render = builtins.replaceStrings tokens values;
in
{
  home.packages = [
    swwwCompat
    # Screenshot stack, bound to Print/Mod+Print below.
    pkgs.grim
    pkgs.slurp
    pkgs.satty
    pkgs.wl-clipboard
  ];

  # Generate the Niri config from the tool-editable template.
  xdg.configFile."niri/config.kdl".text = render (builtins.readFile ./niri/config.kdl.tmpl);

  # Expose the live Stylix palette to nirinator so it can render `@baseXX@`
  # tokens with correct hex when validating with `niri validate`.
  xdg.configFile."nirinator/palette.json".text = builtins.toJSON palette;
}
