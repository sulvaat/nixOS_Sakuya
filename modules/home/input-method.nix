# Seed a default fcitx5 profile so the input-method group already contains Mozc
# on first launch — otherwise fcitx5 starts with only the keyboard layout and
# Ctrl+Space has nothing to switch to. DefaultIM is the US keyboard, so input
# starts in English and Ctrl+Space toggles to Japanese (Mozc).
#
# Seeded only if the file doesn't exist yet, and made writable, so fcitx5-
# configtool can still manage it afterward (e.g. to add more languages). The
# system side (fcitx5 + Mozc, Wayland frontend) lives in
# modules/system/input-method.nix; niri autostarts the daemon.
{ config, lib, pkgs, ... }:
let
  profileText = ''
    [Groups/0]
    Name=Default
    Default Layout=us
    DefaultIM=keyboard-us

    [Groups/0/Items/0]
    Name=keyboard-us
    Layout=

    [Groups/0/Items/1]
    Name=mozc
    Layout=

    [GroupOrder]
    0=Default
  '';
  profileFile = pkgs.writeText "fcitx5-profile" profileText;
in
{
  home.activation.seedFcitx5Profile = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    profile="${config.xdg.configHome}/fcitx5/profile"
    if [ ! -e "$profile" ]; then
      run mkdir -p "$(dirname "$profile")"
      run install -m 0644 ${profileFile} "$profile"
    fi
  '';
}
