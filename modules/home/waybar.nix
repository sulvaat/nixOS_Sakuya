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
  # Lists the windows of the currently-focused niri workspace as a single
  # Pango-markup line for the waybar custom module.
  #   * Tiled windows come first, in on-screen order (sorted by
  #     layout.pos_in_scrolling_layout = [column, row], left->right, top->bottom).
  #   * Floating windows follow, in spawn order (ascending id), each prefixed
  #     with a small square marker.
  #   * The focused window is a bold rounded accent pill.
  #   * An urgent (attention-requesting) unfocused window is bold accent-purple
  #     with a ringing-bell prefix, matching the urgent-workspace styling.
  #   * Everything else is dimmed. Titles are XML-escaped so stray & < > don't
  #     break the markup.
  # Non-ASCII glyphs are literal (codepoints verified present in the font):
  #   … = ellipsis   ▪ = floating square   󰂜 = bell (ring, U+F009C)
  #    /  = powerline left/right half-circle pill caps.
  niriWindows = pkgs.writeShellScript "waybar-niri-windows" ''
    ws=$(${pkgs.niri}/bin/niri msg --json workspaces \
      | ${pkgs.jq}/bin/jq '[.[] | select(.is_focused)][0].id')
    [ -z "$ws" ] && exit 0
    [ "$ws" = "null" ] && exit 0
    ${pkgs.niri}/bin/niri msg --json windows \
      | ${pkgs.jq}/bin/jq -r --argjson ws "$ws" '
          def esc: gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;");
          [ .[] | select(.workspace_id == $ws) ] as $all
          | ([ $all[] | select(.is_floating == false) ]
             | sort_by(.layout.pos_in_scrolling_layout)) as $tiled
          | ([ $all[] | select(.is_floating == true) ]
             | sort_by(.id)) as $floating
          | [ ($tiled + $floating)[]
              | (.title // .app_id // "window") as $raw
              | ($raw | if (length > 28) then (.[0:27] + "…") else . end | esc) as $t
              | (if .is_floating then "▪ " + $t else $t end) as $label
              | if .is_focused
                then "<span foreground=\"${colors.base0D}\"></span><span background=\"${colors.base0D}\" foreground=\"${colors.base00}\"><b>" + $label + "</b></span><span foreground=\"${colors.base0D}\"></span>"
                elif .is_urgent
                then "<span foreground=\"${colors.base0E}\"><b>󰂜 " + $label + "</b></span>"
                else "<span foreground=\"${colors.base04}\">" + $label + "</span>"
                end
            ]
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
