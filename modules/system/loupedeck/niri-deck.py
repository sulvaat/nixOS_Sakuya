#!@python@ -I
"""niri-deck: niri windows + per-window audio for Bitfocus Companion (Loupedeck Live).

Modes (Companion runs the short ones via "System: Run shell command"):
  niri-deck feed               background loop; publishes Companion custom variables
                                 niri      JSON list of 12 slots {id,t,a,s,f,b,c}
                                 niri_sel  JSON of the long-pressed window {id,t,a,o}
  niri-deck tap ROW COL        toggle mute for the window shown on that touch button
  niri-deck select ROW COL     remember that window for the window-options page
  niri-deck act ACTION [ARG]   act on the remembered window:
                                 focus | close | float | fullscreen | center |
                                 maximize | width 50% | width +5% | monitor DP-1 |
                                 colleft | colright | wsup | wsdown
  niri-deck vol up|down|mute   master output volume (+-2%, capped at 100%)
  niri-deck mic up|down|mute   default input (mic) volume (capped at 150%)
  niri-deck app up|down|mute   the remembered window's own audio streams
  niri-deck media fwd|back|toggle   +-5 s seek / play-pause (playerctl)
  niri-deck media next|prev|restart track skip / restart current track
  niri-deck grid next|prev|first     page the window grid (12 windows per page)
  niri-deck hud next|prev|toggle     MangoHud preset 1-4 / show-hide (rewrites its config)

Also publishes `deck` (JSON) for the knob LEDs on the round buttons:
  {vol, vm, mic, mm, lv, lm, la, lf, lg, gp, lh}: levels and mute flags, plus LED
  colours (decimal RGB) for master / mic / selected app / media / grid (blue when
  there are more pages; gp = "page/pages") / MangoHud (colour per preset, off hidden). Levels fade green
  (100%) -> red (0%); muted blinks red. The media LED shows song position:
  green at the start -> red at the end; dimmed while paused; off with no player.

Slots map onto the Live's 4x3 touch grid (Companion rows 0-2, columns 2-5):
slot = row * 4 + (column - 2). Audio state s: 0 none, 1 playing, 2 muted,
3 paused. Audio streams are matched to windows by walking each stream's process
up its parent chain to a window's pid (browsers play audio from child processes).
"""
import colorsys
import http.client
import json
import os
import subprocess
import sys
import time

NIRI = "@niri@"
PACTL = "@pactl@"
WPCTL = "@wpctl@"
PLAYERCTL = "@playerctl@"
STEP = 2            # % per knob detent (master / mic / app volume)
SEEK = 5            # seconds per knob detent (media seek)
PAUSED_DIM = 0.25   # media LED brightness while paused
MUTE_RED = 0xFF0000
# Window moves for the page-2 knobs; niri has no --id form, so the window is
# focused first.
MOVES = {"colleft": "move-column-left", "colright": "move-column-right",
         "wsup": "move-window-to-workspace-up", "wsdown": "move-window-to-workspace-down"}
SLOTS = 12
PERIOD = 0.4
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "niri-deck")
STATE = os.path.join(RUN, "state.json")
SEL = os.path.join(RUN, "selected")
GRID = os.path.join(RUN, "grid")          # current window-grid page (0-based)
PAGE_BLUE = 0x2060FF                      # grid LED when there are more pages
# MangoHud overlay, driven by rewriting its config (MangoHud and gamescope's
# mangoapp reload it live). Built-in presets: 1 FPS only, 2 horizontal,
# 3 extended, 4 detailed. LED colour per preset; off while hidden.
MH_CONF = os.path.expanduser("~/.config/MangoHud/MangoHud.conf")
MH_PRESETS = [1, 2, 3, 4]
MH_COLOURS = {1: 0x30CC30, 2: 0x30C0C0, 3: 0xE0C000, 4: 0xC040C0}
EMPTY = {"id": 0, "t": "", "a": "", "s": 0, "f": 0, "b": 0, "c": 0}
# Colours (decimal RGB) handed to Companion so button expressions stay simple:
# b = background (focused window highlight), c = audio dot by state s.
FOCUS_BG = 0x1F3A5F
DOT = {1: 0x30CC30, 2: 0xE04040, 3: 0x808080}  # playing, muted, paused


def sh(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=3).stdout
    except Exception:
        return ""


def niri_json(what):
    try:
        return json.loads(sh(NIRI, "msg", "-j", what))
    except Exception:
        return None


def niri_action(*args):
    sh(NIRI, "msg", "action", *args)


def parent(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except Exception:
        return 0


def stream_volume(s):
    """Average channel volume of a sink-input, in percent."""
    try:
        ch = [int(str(c["value_percent"]).rstrip("%")) for c in s["volume"].values()]
        return sum(ch) / len(ch)
    except Exception:
        return 0


def wp_volume(target):
    """(percent, muted) for @DEFAULT_AUDIO_SINK@ / @DEFAULT_AUDIO_SOURCE@."""
    out = sh(WPCTL, "get-volume", target)  # e.g. "Volume: 0.45 [MUTED]"
    try:
        pct = float(out.split()[1]) * 100
    except (IndexError, ValueError):
        pct = 0.0
    return pct, "[MUTED]" in out


def level_colour(pct, muted, blink_on):
    """LED colour: green at 100% fading through yellow to red at 0%; muted blinks red."""
    if muted:
        return MUTE_RED if blink_on else 0
    x = max(0.0, min(1.0, pct / 100))
    r, g, b = colorsys.hsv_to_rgb(x / 3, 1, 1)  # hue 120deg (green) -> 0deg (red)
    return (round(r * 255) << 16) | (round(g * 255) << 8) | round(b * 255)


def dim(colour, factor):
    r, g, b = (colour >> 16) & 255, (colour >> 8) & 255, colour & 255
    return (round(r * factor) << 16) | (round(g * factor) << 8) | round(b * factor)


def media_colour():
    """Song-position LED: start green -> end red (same gradient as the volume LEDs,
    inverted); dimmed while paused; off when there's no player or no track length."""
    out = sh(PLAYERCTL, "metadata", "--format", "{{status}}|{{position}}|{{mpris:length}}").strip()
    try:
        status, pos, length = out.split("|")
        frac = max(0.0, min(1.0, int(pos) / int(length)))
    except (ValueError, ZeroDivisionError):
        return 0
    colour = level_colour((1 - frac) * 100, False, True)
    if status == "Playing":
        return colour
    return dim(colour, PAUSED_DIM) if status == "Paused" else 0


def app_label(app_id):
    # com.mitchellh.ghostty -> ghostty, org.gnome.Nautilus -> Nautilus
    return (app_id or "").rsplit(".", 1)[-1][:24]


def snapshot():
    """All windows (ordered like the screen) plus their matched audio streams."""
    windows = niri_json("windows")
    if windows is None:
        return None
    workspaces = {w["id"]: w for w in (niri_json("workspaces") or [])}
    outputs = niri_json("outputs") or {}
    out_x = {n: (o.get("logical") or {}).get("x", 1e9) for n, o in outputs.items()}
    try:
        inputs = json.loads(sh(PACTL, "-f", "json", "list", "sink-inputs") or "[]")
    except Exception:
        inputs = []

    # Map each audio stream to a window via the stream's process ancestry.
    by_pid = {w["pid"]: w["id"] for w in windows if w.get("pid")}
    streams = {}
    for s in inputs:
        try:
            pid = int(s["properties"].get("application.process.id", 0))
        except (TypeError, ValueError):
            continue
        for _ in range(64):
            if pid <= 1:
                break
            if pid in by_pid:
                streams.setdefault(by_pid[pid], []).append(s)
                break
            pid = parent(pid)

    def key(w):
        ws = workspaces.get(w.get("workspace_id"), {})
        pos = (w.get("layout") or {}).get("pos_in_scrolling_layout") or [1e6, 1e6]
        return (out_x.get(ws.get("output"), 1e9), ws.get("idx", 99),
                bool(w.get("is_floating")), list(pos), w["id"])

    result = []
    for w in sorted(windows, key=key):
        st = streams.get(w["id"], [])
        if not st:
            state = 0
        elif all(s.get("mute") for s in st):
            state = 2
        elif any(not s.get("mute") and not s.get("corked") for s in st):
            state = 1
        else:
            state = 3
        ws = workspaces.get(w.get("workspace_id"), {})
        result.append({
            "id": w["id"],
            "t": (w.get("title") or w.get("app_id") or "window")[:48],
            "a": app_label(w.get("app_id")),
            "s": state,
            "f": 1 if w.get("is_focused") else 0,
            "b": FOCUS_BG if w.get("is_focused") else 0,
            "c": DOT.get(state, 0),
            "o": ws.get("output") or "",
            "streams": [s["index"] for s in st],
            "vol": round(sum(stream_volume(s) for s in st) / len(st)) if st else 0,
        })
    return result


class Companion:
    def __init__(self):
        self.conn = None
        self.last = {}
        self.warned = set()

    def set(self, name, value, force=False):
        if not force and self.last.get(name) == value:
            return
        try:
            if self.conn is None:
                self.conn = http.client.HTTPConnection("127.0.0.1", 8000, timeout=1)
            self.conn.request("POST", f"/api/custom-variable/{name}/value",
                              body=value.encode(), headers={"Content-Type": "text/plain"})
            resp = self.conn.getresponse()
            resp.read()
            if resp.status == 404:
                if name not in self.warned:
                    print(f"Companion has no custom variable '{name}' - create 'niri' and 'niri_sel'",
                          flush=True)
                    self.warned.add(name)
                return
            self.last[name] = value
        except Exception:
            self.conn = None  # Companion not up / restarting; retry next cycle


def read_selected():
    try:
        with open(SEL) as f:
            return int(f.read().strip() or 0)
    except Exception:
        return 0


def read_int(path, default=0):
    try:
        with open(path) as f:
            return int(f.read().strip() or default)
    except Exception:
        return default


def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def mh_read():
    """(preset, hidden) from the MangoHud config; defaults to (3, visible)."""
    preset, hidden = 3, False
    try:
        with open(MH_CONF) as f:
            for line in f:
                line = line.strip()
                if line.startswith("preset="):
                    preset = int(line.split("=", 1)[1])
                elif line == "no_display":
                    hidden = True
    except Exception:
        pass
    return (preset if preset in MH_PRESETS else 3), hidden


def mh_write(preset, hidden):
    # Rewrite in place (not replace): MangoHud's inotify watch is on the file.
    write_text(MH_CONF, "# Managed by niri-deck (Loupedeck knob) - edits are overwritten.\n"
                        f"preset={preset}\n" + ("no_display\n" if hidden else ""))


def publish(comp, force=False):
    windows = snapshot()
    if windows is None:
        return
    # Window-grid paging: show 12 windows per page; clamp if windows closed.
    pages = max(1, -(-len(windows) // SLOTS))
    page = min(max(read_int(GRID), 0), pages - 1)
    shown = windows[page * SLOTS:(page + 1) * SLOTS]

    os.makedirs(RUN, exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(shown, f)  # tap/select resolve slots against the visible page
    os.replace(tmp, STATE)

    slots = [{k: w[k] for k in ("id", "t", "a", "s", "f", "b", "c")} for w in shown]
    slots += [EMPTY] * (SLOTS - len(slots))
    comp.set("niri", json.dumps(slots, ensure_ascii=False), force)

    sel_id = read_selected()
    sel = next((w for w in windows if w["id"] == sel_id), None)
    sel_out = ({k: sel[k] for k in ("id", "t", "a", "o", "vol")} if sel
               else {"id": 0, "t": "(no window)", "a": "", "o": "", "vol": 0})
    comp.set("niri_sel", json.dumps(sel_out, ensure_ascii=False), force)

    # Knob LEDs (round buttons): lv master, lm mic, la selected app, lf media position.
    # Muted levels blink, toggling each feed cycle; otherwise this only changes
    # when a level does, so it isn't re-sent every cycle.
    blink_on = int(time.time() / PERIOD) % 2 == 0
    mh_preset, mh_hidden = mh_read()
    vol, vol_m = wp_volume("@DEFAULT_AUDIO_SINK@")
    mic, mic_m = wp_volume("@DEFAULT_AUDIO_SOURCE@")
    app_led = level_colour(sel["vol"], sel["s"] == 2, blink_on) if sel and sel["streams"] else 0
    deck = {"vol": round(vol), "vm": int(vol_m), "mic": round(mic), "mm": int(mic_m),
            "lv": level_colour(vol, vol_m, blink_on),
            "lm": level_colour(mic, mic_m, blink_on),
            "la": app_led,
            "lf": media_colour(),
            "lg": PAGE_BLUE if pages > 1 else 0,
            "gp": f"{page + 1}/{pages}",
            "lh": 0 if mh_hidden else MH_COLOURS.get(mh_preset, 0)}
    comp.set("deck", json.dumps(deck), force)


def slot_window(row, col):
    try:
        with open(STATE) as f:
            windows = json.load(f)
        slot = int(row) * 4 + int(col) - 2
        return windows[slot] if 0 <= slot < len(windows) else None
    except Exception:
        return None


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    comp = Companion()

    if mode == "feed":
        if not os.path.exists(MH_CONF):
            mh_write(3, False)
        while True:
            publish(comp)
            time.sleep(PERIOD)

    elif mode == "tap" and len(argv) == 4:
        w = slot_window(argv[2], argv[3])
        if not w or not w["streams"]:
            return
        mute = "0" if w["s"] == 2 else "1"  # all muted -> unmute, otherwise mute
        for idx in w["streams"]:
            sh(PACTL, "set-sink-input-mute", str(idx), mute)
        publish(comp, force=True)

    elif mode == "select" and len(argv) == 4:
        w = slot_window(argv[2], argv[3])
        os.makedirs(RUN, exist_ok=True)
        with open(SEL, "w") as f:
            f.write(str(w["id"] if w else 0))
        publish(comp, force=True)

    elif mode in ("vol", "mic") and len(argv) == 3:
        target = "@DEFAULT_AUDIO_SINK@" if mode == "vol" else "@DEFAULT_AUDIO_SOURCE@"
        # Ceiling: master stays <=100%; the mic may already be boosted (e.g. 110%),
        # so allow up to 150% rather than clamping it down on the first turn up.
        limit = "1.0" if mode == "vol" else "1.5"
        op = argv[2]
        if op == "up":
            sh(WPCTL, "set-volume", "-l", limit, target, f"{STEP}%+")
        elif op == "down":
            sh(WPCTL, "set-volume", target, f"{STEP}%-")
        elif op == "mute":
            sh(WPCTL, "set-mute", target, "toggle")
        publish(comp, force=True)

    elif mode == "app" and len(argv) == 3:  # the long-pressed window's audio
        w = next((x for x in (snapshot() or []) if x["id"] == read_selected()), None)
        if w and w["streams"]:
            op = argv[2]
            if op == "mute":
                mute = "0" if w["s"] == 2 else "1"
                for idx in w["streams"]:
                    sh(PACTL, "set-sink-input-mute", str(idx), mute)
            elif op in ("up", "down"):
                new = max(0, min(100, w["vol"] + (STEP if op == "up" else -STEP)))
                for idx in w["streams"]:
                    sh(PACTL, "set-sink-input-volume", str(idx), f"{new}%")
        publish(comp, force=True)

    elif mode == "grid" and len(argv) == 3:  # page through windows, 12 at a time
        op = argv[2]
        page = read_int(GRID)
        page = 0 if op == "first" else max(0, page + (1 if op == "next" else -1))
        write_text(GRID, str(page))  # publish() clamps to the real page count
        publish(comp, force=True)

    elif mode == "hud" and len(argv) == 3:  # MangoHud layout / visibility
        preset, hidden = mh_read()
        op = argv[2]
        if op == "toggle":
            hidden = not hidden
        elif op in ("next", "prev"):
            i = MH_PRESETS.index(preset) + (1 if op == "next" else -1)
            preset, hidden = MH_PRESETS[i % len(MH_PRESETS)], False
        mh_write(preset, hidden)
        publish(comp, force=True)

    elif mode == "media" and len(argv) == 3:
        op = argv[2]
        if op == "fwd":
            sh(PLAYERCTL, "position", f"{SEEK}+")
        elif op == "back":
            sh(PLAYERCTL, "position", f"{SEEK}-")
        elif op == "next":
            sh(PLAYERCTL, "next")
        elif op == "prev":
            sh(PLAYERCTL, "previous")
        elif op == "restart":
            sh(PLAYERCTL, "position", "0")
        elif op == "toggle":
            sh(PLAYERCTL, "play-pause")
        publish(comp, force=True)  # update the position LED right after a seek

    elif mode == "act" and len(argv) >= 3:
        wid = str(read_selected())
        if wid == "0":
            return
        action, arg = argv[2], (argv[3] if len(argv) > 3 else "")
        simple = {"focus": "focus-window", "close": "close-window",
                  "float": "toggle-window-floating", "fullscreen": "fullscreen-window",
                  "center": "center-window"}
        if action in simple:
            niri_action(simple[action], "--id", wid)
        elif action == "width" and arg:
            niri_action("set-window-width", "--id", wid, arg)
        elif action == "monitor" and arg:
            niri_action("move-window-to-monitor", "--id", wid, arg)
        elif action == "maximize":  # no --id form: focus it first
            niri_action("focus-window", "--id", wid)
            niri_action("maximize-column")
        elif action in MOVES:  # column/workspace moves have no --id form either
            niri_action("focus-window", "--id", wid)
            niri_action(MOVES[action])
        else:
            print(f"unknown action: {action}", file=sys.stderr)
            return
        publish(comp, force=True)

    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main(sys.argv)
