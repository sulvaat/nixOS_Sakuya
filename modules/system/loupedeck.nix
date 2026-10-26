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
  # VU-meter feed for the Loupedeck side strips. Records the monitor of the
  # current default output (so it follows the Waybar audio switcher, AirPlay
  # included), measures each channel's peak ~25x/s, maps -48..0 dBFS to 0..100
  # with instant attack and smooth release, and pushes the values into the
  # Companion custom variables `vu_l` / `vu_r` (create those in Companion first;
  # unknown variables return 404). Only changed values are sent, so silence
  # costs nothing. `--print` prints levels instead of posting (for testing).
  vuFeed = pkgs.writeScript "companion-vu-feed" ''
    #!${pkgs.python3}/bin/python3 -I
    import array, http.client, math, subprocess, sys, time

    PAREC = "${pkgs.pulseaudio}/bin/parec"
    PACTL = "${pkgs.pulseaudio}/bin/pactl"
    RATE, CH, FPS = 48000, 2, 25
    BLOCK = RATE // FPS * CH * 2          # bytes per frame (s16le stereo)
    FLOOR_DB = -48.0                       # bottom of the meter
    RELEASE = 26.0 / FPS / -FLOOR_DB * 100 # fall speed: 26 dB/s, in meter units
    PRINT = "--print" in sys.argv

    def default_sink():
        try:
            return subprocess.run([PACTL, "get-default-sink"], capture_output=True,
                                  text=True, timeout=2).stdout.strip()
        except Exception:
            return ""

    def start_capture(sink):
        return subprocess.Popen(
            [PAREC, f"--device={sink}.monitor", "--format=s16le", f"--rate={RATE}",
             f"--channels={CH}", "--latency-msec=20", "--raw"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)

    conn = None
    warned = False
    def post(name, value):
        global conn, warned
        if PRINT:
            return
        try:
            if conn is None:
                conn = http.client.HTTPConnection("127.0.0.1", 8000, timeout=1)
            conn.request("POST", f"/api/custom-variable/{name}/value?value={value}")
            resp = conn.getresponse(); resp.read()
            if resp.status == 404 and not warned:
                print(f"Companion has no custom variable '{name}' - create vu_l and vu_r", flush=True)
                warned = True
        except Exception:
            conn = None  # Companion not up yet / restarting; retry next frame

    def to_meter(samples):
        peak = max(max(samples), -min(samples)) if samples else 0
        if peak <= 0:
            return 0.0
        db = 20 * math.log10(peak / 32768)
        return max(0.0, min(100.0, (db - FLOOR_DB) / -FLOOR_DB * 100))

    level, sent = [0.0, 0.0], [None, None]
    sink, proc, frame = None, None, 0
    while True:
        if frame % FPS == 0:  # once a second: follow default-output changes
            cur = default_sink()
            if cur and cur != sink:
                if proc:
                    proc.kill(); proc.wait()
                sink, proc = cur, start_capture(cur)
        frame += 1
        data = proc.stdout.read(BLOCK) if proc else b""
        if len(data) < BLOCK:  # capture died (e.g. pipewire restart): retry
            if proc:
                proc.kill(); proc.wait()
            sink, proc = None, None
            time.sleep(1); frame = 0
            continue
        s = array.array("h", data)
        for ch, name in ((0, "vu_l"), (1, "vu_r")):
            level[ch] = max(to_meter(s[ch::CH]), level[ch] - RELEASE)
            v = round(level[ch])
            if v != sent[ch]:
                sent[ch] = v
                post(name, v)
        if PRINT:
            print(f"\r{sink[:40]:40} L {sent[0]:3d} R {sent[1]:3d}", end="", flush=True)
  '';
  # niri window list + per-window audio for the Live's touch grid (tap = mute,
  # long-press = window-options page). Source: ./loupedeck/niri-deck.py.
  niriDeck = pkgs.writeScriptBin "niri-deck" (builtins.replaceStrings
    [ "@python@" "@niri@" "@pactl@" "@wpctl@" "@playerctl@" ]
    [ "${pkgs.python3}/bin/python3" "${config.programs.niri.package}/bin/niri" "${pkgs.pulseaudio}/bin/pactl"
      "${pkgs.wireplumber}/bin/wpctl" "${pkgs.playerctl}/bin/playerctl" ]
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

  # Pushes live output levels into Companion for the strip VU meters (see vuFeed).
  systemd.user.services.companion-vu-feed = {
    description = "Feed default-output audio levels into Companion (Loupedeck VU meters)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" "bitfocus-companion.service" "pipewire-pulse.service" ];
    serviceConfig = {
      ExecStart = "${vuFeed}";
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
