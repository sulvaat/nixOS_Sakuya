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

  # macOS-style output switcher for the volume icon. Clicking it drops a small
  # Fuzzel menu at the top-right listing every output (local devices and
  # AirPlay/RAOP sinks such as the Sonos), with the current one ticked. Picking
  # one makes it the default and moves already-playing streams onto it, so the
  # switch is immediate. The last entry opens pavucontrol ("Sound Settings…").
  # Clicking the icon again while the menu is open closes it.
  audioSwitch =
    let
      pactl = "${pkgs.pulseaudio}/bin/pactl"; # client only; talks to pipewire-pulse
      jq = "${pkgs.jq}/bin/jq";
    in
    pkgs.writeShellScript "waybar-audio-switch" ''
      ${pkgs.procps}/bin/pkill -f -- '--namespace=audio-switch' && exit 0

      default=$(${pactl} get-default-sink)
      # One TSV row per sink: name, menu label, icon fallback list.
      rows=$(${pactl} -f json list sinks | ${jq} -r --arg def "$default" '
        .[]
        | (.name | test("raop")) as $air
        | (.description
            | if test("\\[[^]]+\\]$") and (test("HDMI") or test("DP"))
              then capture("\\[(?<mon>[^]]+)\\]$").mon + " (HDMI)"  # name the monitor, not the GPU
              else sub(" Analog Stereo$"; "") | sub(" Pro$"; "")
              end) as $desc
        | [ .name,
            ((if .name == $def then "✓  " else "     " end)
              + $desc + (if $air then "  · AirPlay" else "" end)),
            (if $air then "network-wireless,airplay"
             elif (.name | test("hdmi")) then "video-display,audio-card"
             else (.properties["device.icon_name"] // "audio-speakers") + ",audio-speakers"
             end) ]
        | @tsv')

      names=(); sel=0; i=0
      while IFS=$'\t' read -r n _ _; do
        names+=("$n"); [ "$n" = "$default" ] && sel=$i; i=$((i + 1))
      done <<< "$rows"

      idx=$( { while IFS=$'\t' read -r _ label icon; do
                 printf '%s\0icon\x1f%s\n' "$label" "$icon"
               done <<< "$rows"
               printf '%s\0icon\x1f%s\n' "     Sound Settings…" "preferences-desktop-sound,multimedia-volume-control"
             } | ${pkgs.fuzzel}/bin/fuzzel --dmenu --index --namespace=audio-switch \
                   --anchor=top-right --x-margin=12 --y-margin=6 --width=44 \
                   --minimal-lines --hide-prompt --select-index="$sel" ) || exit 0

      if [ "$idx" -ge "''${#names[@]}" ]; then
        exec ${pkgs.pavucontrol}/bin/pavucontrol
      fi
      target=''${names[$idx]}
      ${pactl} set-default-sink "$target"
      ${pactl} -f json list sink-inputs | ${jq} -r '.[].index' \
        | while read -r s; do ${pactl} move-sink-input "$s" "$target"; done
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
  swaync = pkgs.swaynotificationcenter;
  barSettings = barData // {
    "custom/windows" = barData."custom/windows" // { exec = "${niriWindows}"; };
    # Point the swaync module at the real swaync-client (store path can't live in
    # the JSON pre-fromJSON, so graft it on here like custom/windows).
    "custom/swaync" = barData."custom/swaync" // {
      exec = "${swaync}/bin/swaync-client -swb";
      on-click = "${swaync}/bin/swaync-client -t -sw";
      on-click-right = "${swaync}/bin/swaync-client -d -sw";
    };
    # Volume icon: left-click = output switcher menu, right-click = full mixer.
    # (Overrides the plain "pavucontrol" on-click in config.json.)
    pulseaudio = barData.pulseaudio // {
      on-click = "${audioSwitch}";
      on-click-right = "${pkgs.pavucontrol}/bin/pavucontrol";
    };
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
