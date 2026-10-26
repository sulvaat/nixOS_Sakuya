# Loupedeck Live via Bitfocus Companion.
#
# Loupedeck ships no Linux software. Companion (packaged in nixpkgs) drives the
# Loupedeck Live / Live S / CT as a control surface. It runs as a background
# server; configure buttons, dials and touch pages in its web UI at
# http://127.0.0.1:8000 (the "Companion" app-menu entry opens it).
{ config, pkgs, ... }:
let
  # Companion gives a surface add-on 5 s to open a device. Right after power-up
  # the Live needs ~9 s (the add-on clears every display, and the first 194 KB
  # main-display draw alone takes 4-8 s). Companion then gives up while the
  # add-on finishes anyway and keeps the port, so the panel shows its logo, goes
  # dark, and every rescan or replug fails with "already opened" until Companion
  # restarts. Patch the open call to wait 30 s instead. Only dist/main.js is
  # copied and patched; everything else is symlinked, so there's no rebuild.
  # --replace-fail stops the build if an update changes the code, so the patch
  # can be checked (and dropped if upstream fixes it).
  #
  # Second patch: nixpkgs makes Companion run every add-on on its own Node 26,
  # whatever runtime the add-on's manifest asks for. Under Node 26 the serial-port
  # library's poll handle makes the event loop spin (~26k empty epoll wakeups/s,
  # 30-100% of a core even with the panel idle; Node 22/24 with the same load:
  # ~1%). Give add-ons that declare runtime "node22" (the Loupedeck one, and the
  # built-in Stream Deck / X-keys ones) Node 22, as upstream Companion does.
  companion = pkgs.runCommand "bitfocus-companion-${pkgs.bitfocus-companion.version}-loupedeck" { } ''
    src=${pkgs.bitfocus-companion}
    app=share/bitfocus-companion
    mkdir -p $out/bin $out/$app/dist
    for f in $src/$app/*; do [ "''${f##*/}" = dist ] || ln -s $f $out/$app/; done
    for f in $src/$app/dist/*; do [ "''${f##*/}" = main.js ] || ln -s $f $out/$app/dist/; done
    cp $src/$app/dist/main.js $out/$app/dist/main.js
    substituteInPlace $out/$app/dist/main.js --replace-fail \
      'sendWithCb("openScannedDevice",{device:e.scannedDeviceInfo,resolvedSurfaceId:r})' \
      'sendWithCb("openScannedDevice",{device:e.scannedDeviceInfo,resolvedSurfaceId:r},void 0,3e4)'
    node=$(grep -o 'return"/nix/store/[a-z0-9]*-nodejs-[0-9.]*/bin/node"' $out/$app/dist/main.js)
    [ "$(echo "$node" | wc -l)" = 1 ] && [ -n "$node" ] || { echo "getNodeJsPath patch target not found"; exit 1; }
    substituteInPlace $out/$app/dist/main.js --replace-fail "$node" \
      "return t===\"node22\"?\"${pkgs.nodejs_22}/bin/node\":''${node#return}"
    sed "s|$src/$app/dist/main.js|$out/$app/dist/main.js|" $src/bin/bitfocus-companion > $out/bin/bitfocus-companion
    chmod +x $out/bin/bitfocus-companion
    grep -q "$out/$app/dist/main.js" $out/bin/bitfocus-companion
  '';

  # USB permissions. The Live appears as a USB serial port (/dev/ttyACM*, vendor
  # 2ec2) owned by root:dialout. Rather than putting the user in dialout (every
  # serial port), grant the logged-in seat user access to Loupedeck devices only
  # via "uaccess". That tag is applied by systemd's 73-seat-late.rules, so this
  # must be a low-numbered rules file (services.udev.extraRules lands in
  # 99-local.rules, which is too late for uaccess). ID_MM_DEVICE_IGNORE keeps
  # ModemManager from probing the port as a modem and interfering with it.
  loupedeckUdev = pkgs.writeTextFile {
    name = "loupedeck-udev-rules";
    destination = "/lib/udev/rules.d/70-loupedeck.rules";
    text = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="2ec2", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1"
      SUBSYSTEM=="usb", ATTRS{idVendor}=="2ec2", TAG+="uaccess"
    '';
  };

  # App-menu entry that opens the admin UI (Companion has no window of its own).
  companionUi = pkgs.makeDesktopItem {
    name = "bitfocus-companion";
    desktopName = "Companion";
    comment = "Configure the Loupedeck Live (Bitfocus Companion web UI)";
    exec = "${pkgs.xdg-utils}/bin/xdg-open http://127.0.0.1:8000";
    icon = "input-dialpad";
    categories = [ "AudioVideo" "Utility" ];
  };
  # niri window list + per-window audio for the Live's touch grid (tap = mute,
  # long-press = window-options page). Source: ./loupedeck/niri-deck.py.
  niriDeck = pkgs.writeScriptBin "niri-deck" (builtins.replaceStrings
    [ "@python@" "@niri@" "@pactl@" "@wpctl@" "@playerctl@" "@pwlink@" "@pwmetadata@" ]
    [ "${pkgs.python3}/bin/python3" "${config.programs.niri.package}/bin/niri" "${pkgs.pulseaudio}/bin/pactl"
      "${pkgs.wireplumber}/bin/wpctl" "${pkgs.playerctl}/bin/playerctl"
      "${pkgs.pipewire}/bin/pw-link" "${pkgs.pipewire}/bin/pw-metadata" ]
    (builtins.readFile ./loupedeck/niri-deck.py));
in
{
  services.udev.packages = [ loupedeckUdev ];

  # Companion starts each surface add-on as a child process with an allowlisted
  # environment that omits PATH, so Node falls back to searching /usr/bin:/bin.
  # The Loupedeck add-on lists serial ports by running `udevadm`, which on NixOS
  # lives only in the system profile, so scans failed with "spawn udevadm
  # ENOENT". Expose it at /usr/bin/udevadm (via the stable system-profile path,
  # so it follows systemd updates). Remove if Companion starts passing PATH.
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/udevadm - - - - /run/current-system/sw/bin/udevadm"
  ];
  environment.systemPackages = [ companion companionUi niriDeck ];

  # Start with the desktop session (niri-session brings up graphical-session.target),
  # so the environment niri imports (WAYLAND_DISPLAY etc.) is available to any
  # shell commands Companion runs.
  #   --admin-address 127.0.0.1         admin UI reachable from this machine only
  #   --enable-shell-command-support    allow "run shell command" actions (launch
  #                                     apps, wpctl volume, scripts). Safe-ish only
  #                                     because the UI is localhost-bound; drop the
  #                                     flag if you don't need local commands.
  systemd.user.services.bitfocus-companion = {
    description = "Bitfocus Companion (Loupedeck Live control surface)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      # Fix the Loupedeck add-on (Companion installs it under ~/.config, so it
      # can't be patched in the store): reset the panel's stale WebSocket session
      # before the handshake, release the port on failure, time out lost acks.
      # Details in the script; it only warns if an add-on update changed the code.
      ExecStartPre = "${pkgs.python3}/bin/python3 -I ${./loupedeck/patch-addon.py}";
      ExecStart = "${companion}/bin/bitfocus-companion --admin-address 127.0.0.1 --admin-port 8000 --enable-shell-command-support";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  # Locks the Live's serial port to Companion (Proton opening it as a controlling
  # terminal hung it up overnight) and rescans if the panel is plugged in but
  # Companion isn't holding it. Details in ./loupedeck/guard.py.
  systemd.user.services.loupedeck-guard = {
    description = "Keep the Loupedeck locked to Companion and reconnect it";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "bitfocus-companion.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 -I ${./loupedeck/guard.py}";
      Restart = "always";
      RestartSec = 3;
    };
  };

  # Publishes the niri window list / selected window into Companion (see niriDeck).
  systemd.user.services.niri-deck-feed = {
    description = "Feed niri windows and per-window audio into Companion (Loupedeck)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "bitfocus-companion.service" "pipewire-pulse.service" ];
    serviceConfig = {
      ExecStart = "${niriDeck}/bin/niri-deck feed";
      Restart = "always";
      RestartSec = 3;
    };
  };
}
