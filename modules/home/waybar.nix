# Waybar status bar, plus the helper script that lists windows in the focused
# Niri workspace.
#
# Bar settings live in ./waybar/config.json and the stylesheet in
# ./waybar/style.css.tmpl as tool-editable data (edited by the `nirinator` TUI).
# In the CSS template, Stylix colors are `@baseXX@` tokens; in the JSON, the
# windows-helper path is the `@niri_windows@` token. Both are substituted below,
# so the rendered output is unchanged.
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

  colors = osConfig.lib.stylix.colors.withHashtag;
  slots = [
    "base00" "base01" "base02" "base03" "base04" "base05" "base06" "base07"
    "base08" "base09" "base0A" "base0B" "base0C" "base0D" "base0E" "base0F"
  ];
  renderColors = builtins.replaceStrings (map (n: "@${n}@") slots) (map (n: colors.${n}) slots);

  # Parse the tool-editable JSON as pure data (fromJSON forbids store-path
  # context in its input), then graft the real windows-helper path onto the
  # `@niri_windows@` placeholder in the custom/windows module.
  barData = builtins.fromJSON (builtins.readFile ./waybar/config.json);
  barSettings = barData // {
    "custom/windows" = barData."custom/windows" // { exec = "${niriWindows}"; };
  };
in
{
  programs.waybar = {
    enable = true;
    # Launched by niri's spawn-at-startup, so no systemd service (avoids a
    # duplicate stacked bar).
    systemd.enable = false;

    settings.mainBar = barSettings;

    style = lib.mkForce (renderColors (builtins.readFile ./waybar/style.css.tmpl));
  };
}
