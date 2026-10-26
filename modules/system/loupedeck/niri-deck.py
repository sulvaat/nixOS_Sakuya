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
  niri-deck out system ROW COL       page 3: make that device the system output
  niri-deck out app ROW COL          page 4: pin the held window's audio to that
                                       device (tap its pinned device again to un-pin)
  niri-deck out follow               page 4: un-pin (follow the system output)
  niri-deck mirror a left|right|press  page 3: pick / lock (red) mirror source A
  niri-deck mirror b left|right|press  page 3: pick target B / confirm: adds A -> B,
                                       or removes it if it exists (loops refused)
  niri-deck mirror m left|right|press  page 3: step through saved mirrors / delete one
  niri-deck dev a|b up|down|mute     page 3: volume of the picked A / B device

Also publishes `deck` (JSON) for the knob LEDs on the round buttons:
  {vol, vm, mic, mm, lv, lm, la, lf, lg, gp, lh}: levels and mute flags, plus LED
  colours (decimal RGB) for master / mic / selected app / media / grid (blue when
  there are more pages; gp = "page/pages") / MangoHud (colour per preset, off hidden). Levels fade green
  (100%) -> red (0%); muted blinks red. The media LED shows song position:
  green at the start -> red at the end; dimmed while paused; off with no player.

And `strip` (JSON list of 24) for the LCD strips, which label and show the knob
beside each cell: {l label, v value text, f bar fill 0-100 or -1, c bar colour,
vc value colour}. Page 1: VOL MIC media | GRID HUD TRACK; page 2: app MIC media |
WIDTH COLUMN WS; page 3: A, A VOL, media | B, B VOL, MIRRORS; page 4: app MIC
media | OUTPUT FOR, NOW ON, FOLLOWS. Companion picks a cell with
($(this:page) - 1) * 6 + ($(this:column) == 6 ? 3 : 0) + $(this:row).

And `audio` (JSON list of 24) for the device boards on pages 3 and 4; see board().
`deck` also carries lo (system output colour) and lao (held app's output colour)
for the 3/3 LED.

Slots map onto the Live's 4x3 touch grid (Companion rows 0-2, columns 2-5):
slot = row * 4 + (column - 2). Audio state s: 0 none, 1 playing, 2 muted,
3 paused. Audio streams are matched to windows by walking each stream's process
up its parent chain to a window's pid (browsers play audio from child processes).
"""
import colorsys
import http.client
import json
import os
import re
import subprocess
import sys
import threading
import time

NIRI = "@niri@"
PACTL = "@pactl@"
WPCTL = "@wpctl@"
PLAYERCTL = "@playerctl@"
PW_LINK = "@pwlink@"
PW_METADATA = "@pwmetadata@"
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
# Every change to `niri` makes Companion redraw all 12 touch buttons, and the
# Live's main display is slow to draw. Apps that animate their title (terminal
# spinners like Claude Code's, progress counters) would otherwise trigger a full
# redraw every second, so spinner glyphs are stripped and title-only changes are
# sent at most every TITLE_HOLD seconds (focus/audio/window changes go at once).
TITLE_HOLD = 3.0
SPINNER = re.compile(r"^[⠀-⣿◐-◓○●✢-✽·*]+\s*")
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
MH_NAMES = {1: "FPS", 2: "HORIZ", 3: "EXT", 4: "FULL"}
EMPTY = {"id": 0, "t": "", "a": "", "s": 0, "f": 0, "b": 0, "c": 0}
# Strip readouts: each LCD-strip cell labels and shows the knob beside it.
WHITE = 0xFFFFFF
GREY = 0x9AA0A6
LAYOUT_BLUE = 0x6080FF
# Colours (decimal RGB) handed to Companion so button expressions stay simple:
# b = background (focused window highlight), c = audio dot by state s.
FOCUS_BG = 0x1F3A5F
DOT = {1: 0x30CC30, 2: 0xE04040, 3: 0x808080}  # playing, muted, paused

# Audio pages. Page 3 (from 3/3 on page 1): every output device; tap = system
# output, left-top knob picks and locks mirror source A (red), right-top picks
# target B and confirms. Page 4 (from 3/3 on page 2): tap = pin the held
# window's app to that device. Each device keeps a colour (by first-seen order,
# known devices get a fixed one) in COLOURS; mirrors live in MIRRORS and are
# re-linked whenever both devices exist.
PERSIST = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
                       "niri-deck")
COLOURS = os.path.join(PERSIST, "colours.json")   # {sink name: colour}, in board order
MIRRORS = os.path.join(PERSIST, "mirrors.json")   # [[source sink, target sink], ...]
AUDIO_UI = os.path.join(RUN, "audio.json")         # knob cursors on page 3
KNOWN_COLOURS = [("TEAC", 0xFFFFFF), ("SPDIF", 0xFF8C00), ("Speaker", 0x30CC30),
                 ("Headphones", 0x00C8E0), ("hdmi", 0xA040FF), ("Arc", 0x2060FF),
                 ("Beam", 0x80B0FF), ("MV7", 0xE0C000), ("TASCAM", 0xFF60B0)]
SPARE_COLOURS = [0x9AE000, 0x00A090, 0xFFB000, 0xC0A0FF, 0xFF8070, 0x40E0A0,
                 0xD0D060, 0x6060FF, 0xE070E0, 0x70C0A0]  # no red: it marks a locked A
LOCK_RED = 0xB00000
CURSOR_IDLE = 60      # s: forget an unconfirmed A/B pick
EMPTY_DEV = {"n": "", "c": 0, "s": "", "sc": GREY, "p": "", "bg": 0, "bw": 0}


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


def volume_pct(s):
    """Average channel volume of a sink, source or sink-input, in percent."""
    try:
        ch = [int(str(c["value_percent"]).rstrip("%")) for c in s["volume"].values()]
        return sum(ch) / len(ch)
    except Exception:
        return 0


def pactl_json(*what):
    try:
        return json.loads(sh(PACTL, "-f", "json", "list", *what) or "[]")
    except Exception:
        return []


def audio_snapshot():
    """Sinks, sources, streams, defaults, app pins and links, in five calls.
    The feed only re-reads this when PipeWire reports a change (AudioWatch)."""
    meta, pins = {}, {}
    for line in sh(PW_METADATA).splitlines():
        # update: id:262 key:'target.object' value:'95' type:'Spa:Id'
        m = re.match(r"update: id:(\d+) key:'([^']*)' value:'(.*)' type:", line)
        if not m:
            continue
        subject, key, value = m.groups()
        if key == "target.object":
            pins[subject] = value      # stream object.id -> pinned sink serial
        elif subject == "0":
            meta[key] = value
    def default(key):
        try:
            return json.loads(meta.get(key, "{}")).get("name", "")
        except ValueError:
            return ""
    links, src = set(), None
    for line in sh(PW_LINK, "-l").splitlines():
        if not line.startswith(" "):
            src = line.strip()
        elif "|->" in line and src:
            links.add((src, line.split("|->", 1)[1].strip()))
    return {"sinks": pactl_json("sinks"), "sources": pactl_json("sources"),
            "inputs": pactl_json("sink-inputs"), "pins": pins, "links": links,
            "sink": default("default.audio.sink"), "source": default("default.audio.source")}


class AudioWatch:
    """`pactl subscribe` in a thread; `changed` is set on any sink/source/stream/
    server event, so the feed re-reads audio state only when something moved."""
    def __init__(self):
        self.changed = threading.Event()
        self.changed.set()
        threading.Thread(target=self.run, daemon=True).start()

    def run(self):
        while True:
            try:
                p = subprocess.Popen([PACTL, "subscribe"], stdout=subprocess.PIPE, text=True)
                for line in p.stdout:
                    if any(w in line for w in ("sink", "source", "server", "card")):
                        self.changed.set()
            except Exception:
                pass
            self.changed.set()
            time.sleep(2)  # pipewire-pulse restarting


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


def media_info():
    """(status, position s, length s or 0, title) of the current player; status "" if none."""
    out = sh(PLAYERCTL, "metadata", "--format",
             "{{status}}|{{position}}|{{mpris:length}}|{{title}}").strip()
    try:
        status, pos, length, title = out.split("|", 3)
        return status, int(pos or 0) / 1e6, int(length or 0) / 1e6, title
    except ValueError:
        return "", 0, 0, ""


def media_colour(info):
    """Song-position LED: start green -> end red (same gradient as the volume LEDs,
    inverted); dimmed while paused; off when there's no player or no track length."""
    status, pos, length, _ = info
    if not length:
        return 0
    frac = max(0.0, min(1.0, pos / length))
    colour = level_colour((1 - frac) * 100, False, True)
    if status == "Playing":
        return colour
    return dim(colour, PAUSED_DIM) if status == "Paused" else 0


def cell(label, value, fill=-1, colour=WHITE, vcolour=WHITE):
    """One strip cell: label, value text, bar fill 0-100 (-1 = no bar), bar / value colours."""
    return {"l": label, "v": value, "f": round(max(0, min(100, fill))) if fill >= 0 else -1,
            "c": colour, "vc": vcolour}


def level_cell(label, pct, muted):
    # Solid red when muted (no blinking: every change redraws the cell).
    if muted:
        return cell(label, "MUTE", pct, MUTE_RED, MUTE_RED)
    return cell(label, f"{round(pct)}%", pct, level_colour(pct, False, True))


def media_cell(info):
    status, pos, length, _ = info
    if status not in ("Playing", "Paused"):
        return cell("MEDIA", "-", vcolour=GREY)
    pos = int(pos)
    return cell("PLAY" if status == "Playing" else "PAUSE", f"{pos // 60}:{pos % 60:02d}",
                pos / length * 100 if length else -1, media_colour(info) or WHITE)


def strip_cells(vol, vol_m, mic, mic_m, info, page, pages, mh_preset, mh_hidden, sel):
    """12 cells: page 1 (left strip rows 0-2, right strip rows 0-2), then page 2.
    Companion indexes them with ($(this:page) - 1) * 6 + (column == 6 ? 3 : 0) + row."""
    vol_c, mic_c, media_c = level_cell("VOL", vol, vol_m), level_cell("MIC", mic, mic_m), media_cell(info)
    hud = (cell("HUD", "OFF", vcolour=GREY) if mh_hidden else
           cell("HUD", MH_NAMES.get(mh_preset, "?"), mh_preset * 25,
                MH_COLOURS.get(mh_preset, WHITE), MH_COLOURS.get(mh_preset, WHITE)))
    page1 = [vol_c, mic_c, media_c,
             cell("GRID", f"{page + 1}/{pages}", (page + 1) / pages * 100 if pages > 1 else -1, PAGE_BLUE),
             hud,
             cell("TRACK", info[3][:40] or "-", vcolour=WHITE if info[3] else GREY)]

    if not sel:
        none = cell("-", "-", vcolour=GREY)
        return page1 + [none, mic_c, media_c, none, none, none]
    app = (level_cell(sel["a"] or "APP", sel["vol"], sel["s"] == 2) if sel["streams"]
           else cell(sel["a"] or "APP", "-", vcolour=GREY))
    if sel["fl"]:
        width = cell("WIDTH", "FLOAT", vcolour=GREY)
        column = cell("COLUMN", "-", vcolour=GREY)
    else:
        width = cell("WIDTH", f"{sel['wpct']}%", sel["wpct"], LAYOUT_BLUE)
        column = cell("COLUMN", f"{sel['col']}/{sel['ncol']}",
                      sel["col"] / sel["ncol"] * 100 if sel["ncol"] else -1, LAYOUT_BLUE)
    return page1 + [app, mic_c, media_c, width, column, cell("WS " + sel["o"], str(sel["ws"]))]


def read_json(path, default):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return default


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.replace(tmp, path)


def device_label(sink):
    """The device's own name, tidied; HDMI outputs are named after the monitor."""
    d = sink.get("description") or sink.get("name", "")
    m = re.search(r"\[([^]]+)\]$", d)
    if m and ("HDMI" in d or "DP" in d):
        return m.group(1) + " (HDMI)"
    return re.sub(r" (Analog Stereo|Digital Stereo|Pro)$", "", d)


def devices(audio):
    """Output devices that are present, in board order (first seen first; a newly
    plugged device takes the next slot and keeps its colour from then on)."""
    colours = read_json(COLOURS, {})
    sinks = {s["name"]: s for s in audio["sinks"]}
    # New devices go last; several at once (first run): system output, wired, AirPlay.
    new = sorted((n for n in sinks if n not in colours),
                 key=lambda n: (n != audio["sink"], n.startswith("raop_sink")))
    for n in new:
        text = (n + " " + (sinks[n].get("description") or "")).lower()
        used = set(colours.values())
        colours[n] = (next((c for pat, c in KNOWN_COLOURS if pat.lower() in text and c not in used), None)
                      or next((c for c in SPARE_COLOURS if c not in used),
                              SPARE_COLOURS[len(colours) % len(SPARE_COLOURS)]))
    if new:
        write_json(COLOURS, colours)
    return [{"name": n, "label": device_label(sinks[n]), "colour": c, "serial": str(sinks[n]["index"]),
             "vol": volume_pct(sinks[n]), "mute": bool(sinks[n].get("mute")),
             "air": n.startswith("raop_sink")}
            for n, c in colours.items() if n in sinks][:SLOTS]


def stream_sink(audio, idx):
    """(sink name, pinned) for a sink-input; pinned = it has its own target and
    won't follow the system output."""
    s = next((s for s in audio["inputs"] if s["index"] == idx), None)
    if not s:
        return "", False
    name = next((k["name"] for k in audio["sinks"] if k["index"] == s["sink"]), "")
    return name, s["properties"].get("object.id") in audio["pins"]


def pin_streams(audio, streams, sink=None):
    """Pin streams to a sink (its serial), or un-pin them (sink None) so they
    follow the system output. Uses the metadata WirePlumber watches, so a pin to
    the current system output sticks too (pactl treats that as un-pin), and
    WirePlumber remembers it per app."""
    for s in audio["inputs"]:
        oid = s["properties"].get("object.id")
        if s["index"] not in streams or not oid:
            continue
        if sink:
            sh(PW_METADATA, oid, "target.object", sink["serial"], "Spa:Id")
        else:
            sh(PW_METADATA, "-d", oid, "target.object")
            sh(PW_METADATA, "-d", oid, "target.node")


def mirror_pairs(a, b):
    """[(A monitor port, B input port)]: same channel name where both have it,
    otherwise by order (the TASCAM uses AUX0/1, AirPlay sinks send_FL/FR)."""
    def ports(flag, node):
        return [l.split(":", 1)[1] for l in sh(PW_LINK, flag).splitlines()
                if l.split(":", 1)[0] == node]
    outs = [p for p in ports("-o", a) if p.startswith("monitor_")]
    ins = ports("-i", b)
    pairs = []
    for i, o in enumerate(outs):
        ch = o.split("_", 1)[1]
        dst = next((p for p in ins if p.rsplit("_", 1)[-1] == ch), None) or (ins[i % len(ins)] if ins else None)
        if dst:
            pairs.append((f"{a}:{o}", f"{b}:{dst}"))
    return pairs


def mirror_linked(audio, a, b):
    return any(s.startswith(a + ":monitor_") and d.startswith(b + ":") for s, d in audio["links"])


def sync_mirrors(audio):
    """(Re)create the links for every saved mirror whose devices are both present:
    links vanish on reboot, replug or when PipeWire restarts."""
    names = {s["name"] for s in audio["sinks"]}
    for a, b in read_json(MIRRORS, []):
        if a in names and b in names and not mirror_linked(audio, a, b):
            for src, dst in mirror_pairs(a, b):
                sh(PW_LINK, src, dst)


def unlink_mirror(audio, a, b):
    for src, dst in audio["links"]:
        if src.startswith(a + ":monitor_") and dst.startswith(b + ":"):
            sh(PW_LINK, "-d", src, dst)


def reaches(mirrors, start, goal):
    """True if audio from `start` already flows on to `goal` through mirrors
    (adding goal -> start would then loop)."""
    seen, todo = set(), [start]
    while todo:
        x = todo.pop()
        if x == goal:
            return True
        if x not in seen:
            seen.add(x)
            todo += [b for a, b in mirrors if a == x]
    return False


def read_ui():
    """Page-3 knob state {a, lock, b, m}; dropped after CURSOR_IDLE s untouched."""
    ui = read_json(AUDIO_UI, {})
    return ui if time.time() - ui.get("t", 0) < CURSOR_IDLE else {}


def board(audio, devs, ui, held):
    """24 device keys {n name, c colour, s status, sc status colour, p apps,
    bg background, bw cursor border}: page 3, then page 4 (`held`: the held
    window, whose output page 4 sets). Companion picks one with
    ($(this:page) - 3) * 12 + $(this:row) * 4 + $(this:column) - 2."""
    mirrors = read_json(MIRRORS, [])
    colour = {d["name"]: d["colour"] for d in devs}
    apps = {}
    for s in audio["inputs"]:
        name = s["properties"].get("application.name") or "?"
        apps.setdefault(s["sink"], [])
        if name not in apps[s["sink"]]:
            apps[s["sink"]].append(name)
    held_sink, held_pinned = (stream_sink(audio, held["streams"][0]) if held and held["streams"]
                              else ("", False))
    page3, page4 = [], []
    for d in devs:
        base = {"n": d["label"], "c": d["colour"],
                "p": ", ".join(apps.get(int(d["serial"]), [])), "bg": 0, "bw": 0}
        sources = [a for a, b in mirrors if b == d["name"] and a in colour]
        if d["name"] == audio["sink"]:
            status, sc = "SYSTEM", WHITE
        elif sources:
            status, sc = "+ MIRROR", colour[sources[0]]  # in the source's colour
        else:
            status, sc = ("AIRPLAY" if d["air"] else ""), GREY
        locked = ui.get("lock") and ui.get("a") == d["name"]
        cursor = ui.get("b" if ui.get("lock") else "a") == d["name"]
        page3.append({**base, "s": status, "sc": sc, "bg": LOCK_RED if locked else 0,
                      "bw": 3 if cursor else 0})
        if d["name"] == held_sink:
            page4.append({**base, "s": "PINNED" if held_pinned else "VIA SYSTEM",
                          "sc": WHITE, "bw": 3})
        else:
            page4.append({**base, "s": "SYSTEM" if d["name"] == audio["sink"] else "",
                          "sc": GREY})
    pad = [EMPTY_DEV] * (SLOTS - len(devs))
    return page3 + pad + page4 + pad


def audio_cells(audio, devs, ui, held, app_cell, mic_c, media_c):
    """Strip cells for page 3 (mirror picks A / B, the saved mirrors) and page 4
    (the held app's output)."""
    by = {d["name"]: d for d in devs}
    mirrors = read_json(MIRRORS, [])
    none = lambda label, value="-": cell(label, value, vcolour=GREY)
    a, b, lock = by.get(ui.get("a")), by.get(ui.get("b")), ui.get("lock")
    c_a = cell("A LOCKED" if lock else "PICK A", a["label"], vcolour=a["colour"]) if a else none("PICK A", "turn")
    a_vol = level_cell("A VOL", a["vol"], a["mute"]) if a else none("A VOL")
    if not lock:
        c_b = none("B", "lock A first")
    elif b:
        if [a["name"], b["name"]] in mirrors:
            verb = "REMOVE"
        else:
            verb = "LOOP" if reaches(mirrors, b["name"], a["name"]) else "ADD"
        c_b = cell(f"B · {verb}", b["label"], vcolour=b["colour"])
    else:
        c_b = none("PICK B", "turn")
    b_vol = level_cell("B VOL", b["vol"], b["mute"]) if b else none("B VOL")
    m = ui.get("m")
    if m is not None and 0 <= m < len(mirrors):
        src, dst = mirrors[m]
        label = lambda n: by[n]["label"] if n in by else "(unplugged)"
        c_m = cell(f"MIRROR {m + 1}/{len(mirrors)} · DEL", f"{label(src)} → {label(dst)}",
                   vcolour=by[dst]["colour"] if dst in by else GREY)
    else:
        c_m = cell("MIRRORS", str(len(mirrors)), vcolour=WHITE if mirrors else GREY)
    page3 = [c_a, a_vol, media_c, c_b, b_vol, c_m]

    if not held or not held["streams"]:
        return page3 + [app_cell, mic_c, media_c, none("OUTPUT FOR", held["a"] if held else "-"),
                        none("NOW ON", "no audio"), none("FOLLOW")]
    sink, pinned = stream_sink(audio, held["streams"][0])
    dev = by.get(sink)
    now = (cell("NOW ON", dev["label"], vcolour=dev["colour"]) if dev else none("NOW ON"))
    follow = (cell("PRESS: UNPIN", "PINNED", vcolour=WHITE) if pinned
              else cell("FOLLOWS", "SYSTEM", vcolour=GREY))
    return page3 + [app_cell, mic_c, media_c, cell("OUTPUT FOR", held["a"] or "app"), now, follow]


def app_label(app_id):
    # com.mitchellh.ghostty -> ghostty, org.gnome.Nautilus -> Nautilus
    return (app_id or "").rsplit(".", 1)[-1][:24]


def snapshot(inputs):
    """All windows (ordered like the screen) plus their matched audio streams
    (`inputs`: pactl sink-inputs, from audio_snapshot)."""
    windows = niri_json("windows")
    if windows is None:
        return None
    workspaces = {w["id"]: w for w in (niri_json("workspaces") or [])}
    outputs = niri_json("outputs") or {}
    out_x = {n: (o.get("logical") or {}).get("x", 1e9) for n, o in outputs.items()}

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

    # Columns per workspace, for the page-2 column readout.
    ncols = {}
    for w in windows:
        pos = (w.get("layout") or {}).get("pos_in_scrolling_layout")
        if pos and not w.get("is_floating"):
            ncols[w.get("workspace_id")] = max(ncols.get(w.get("workspace_id"), 0), pos[0])

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
        lay = w.get("layout") or {}
        out_w = ((outputs.get(ws.get("output")) or {}).get("logical") or {}).get("width") or 0
        tile_w = (lay.get("tile_size") or [0])[0]
        result.append({
            "id": w["id"],
            "t": (SPINNER.sub("", w.get("title") or "") or w.get("app_id") or "window")[:48],
            "a": app_label(w.get("app_id")),
            "s": state,
            "f": 1 if w.get("is_focused") else 0,
            "b": FOCUS_BG if w.get("is_focused") else 0,
            "c": DOT.get(state, 0),
            "o": ws.get("output") or "",
            "streams": [s["index"] for s in st],
            "vol": round(sum(volume_pct(s) for s in st) / len(st)) if st else 0,
            # layout, for the page-2 strip readouts
            "fl": 1 if w.get("is_floating") else 0,
            "wpct": round(tile_w / out_w * 100) if out_w else 0,
            "col": (lay.get("pos_in_scrolling_layout") or [0])[0],
            "ncol": ncols.get(w.get("workspace_id"), 0),
            "ws": ws.get("idx", 0),
        })
    return result


class Companion:
    def __init__(self):
        self.conn = None
        self.last = {}
        self.warned = set()
        self.slots_key, self.slots_sent = None, 0.0  # niri throttle (see TITLE_HOLD)

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


def publish(comp, audio, force=False):
    windows = snapshot(audio["inputs"])
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
    key = json.dumps([{k: v for k, v in s.items() if k != "t"} for s in slots])
    if force or key != comp.slots_key or time.time() - comp.slots_sent >= TITLE_HOLD:
        value = json.dumps(slots, ensure_ascii=False)
        if value != comp.last.get("niri"):
            comp.slots_key, comp.slots_sent = key, time.time()
        comp.set("niri", value, force)

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
    sink = next((s for s in audio["sinks"] if s["name"] == audio["sink"]), {})
    source = next((s for s in audio["sources"] if s["name"] == audio["source"]), {})
    vol, vol_m = volume_pct(sink), bool(sink.get("mute"))
    mic, mic_m = volume_pct(source), bool(source.get("mute"))
    app_led = level_colour(sel["vol"], sel["s"] == 2, blink_on) if sel and sel["streams"] else 0
    info = media_info()
    cells = strip_cells(vol, vol_m, mic, mic_m, info, page, pages, mh_preset, mh_hidden, sel)

    # Audio pages 3-4: device board, mirror picks, held app's output.
    devs = devices(audio)
    ui = read_ui()
    cells += audio_cells(audio, devs, ui, sel, cells[6], cells[1], cells[2])
    comp.set("strip", json.dumps(cells, ensure_ascii=False), force)
    comp.set("audio", json.dumps(board(audio, devs, ui, sel), ensure_ascii=False), force)
    colour = {d["name"]: d["colour"] for d in devs}
    held_sink = stream_sink(audio, sel["streams"][0])[0] if sel and sel["streams"] else ""

    deck = {"vol": round(vol), "vm": int(vol_m), "mic": round(mic), "mm": int(mic_m),
            "lo": colour.get(audio["sink"], 0),   # 3/3: system output (pages 1, 3)
            "lao": colour.get(held_sink, 0),      # 3/3: held app's output (pages 2, 4)
            "lv": level_colour(vol, vol_m, blink_on),
            "lm": level_colour(mic, mic_m, blink_on),
            "la": app_led,
            "lf": media_colour(info),
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


def held_window(audio):
    return next((w for w in (snapshot(audio["inputs"]) or []) if w["id"] == read_selected()), None)


def step(devs, name, op, skip=None):
    """Next/previous device name on the board from `name` (wrapping), skipping `skip`."""
    names = [d["name"] for d in devs if d["name"] != skip]
    if not names:
        return None
    if name not in names:
        return names[0]
    return names[(names.index(name) + (1 if op == "right" else -1)) % len(names)]


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    comp = Companion()

    if mode == "feed":
        if not os.path.exists(MH_CONF):
            mh_write(3, False)
        watch, audio, read_at = AudioWatch(), None, 0.0
        while True:
            # Audio state is only re-read when PipeWire reports a change (or every
            # 30 s as a safety net); clear first so a change mid-read isn't lost.
            if watch.changed.is_set() or time.time() - read_at > 30:
                watch.changed.clear()
                audio, read_at = audio_snapshot(), time.time()
                sync_mirrors(audio)
            publish(comp, audio)
            time.sleep(PERIOD)

    audio = audio_snapshot()

    if mode == "tap" and len(argv) == 4:
        w = slot_window(argv[2], argv[3])
        if not w or not w["streams"]:
            return
        mute = "0" if w["s"] == 2 else "1"  # all muted -> unmute, otherwise mute
        for idx in w["streams"]:
            sh(PACTL, "set-sink-input-mute", str(idx), mute)

    elif mode == "select" and len(argv) == 4:
        w = slot_window(argv[2], argv[3])
        os.makedirs(RUN, exist_ok=True)
        with open(SEL, "w") as f:
            f.write(str(w["id"] if w else 0))

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

    elif mode == "app" and len(argv) == 3:  # the long-pressed window's audio
        w = held_window(audio)
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

    elif mode == "out" and len(argv) >= 3:  # pages 3-4: pick an output device
        devs, op = devices(audio), argv[2]
        if op in ("system", "app") and len(argv) == 5:
            slot = int(argv[3]) * 4 + int(argv[4]) - 2
            dev = devs[slot] if 0 <= slot < len(devs) else None
            if dev and op == "system":
                sh(PACTL, "set-default-sink", dev["name"])
            elif dev:  # tapping the device the app is pinned to un-pins it
                w = held_window(audio)
                if w and w["streams"]:
                    sink, pinned = stream_sink(audio, w["streams"][0])
                    pin_streams(audio, w["streams"], None if pinned and sink == dev["name"] else dev)
        elif op == "follow":  # un-pin the held app: back to the system output
            w = held_window(audio)
            if w and w["streams"]:
                pin_streams(audio, w["streams"])

    elif mode == "mirror" and len(argv) == 4:  # page 3 knobs: A, B, saved mirrors
        devs, ui, mirrors = devices(audio), read_ui(), read_json(MIRRORS, [])
        knob, op = argv[2], argv[3]
        if knob == "a" and op in ("left", "right"):
            # Turning A again releases a lock: nothing changes until B is confirmed.
            ui = {"a": step(devs, ui.get("a") or audio["sink"], op) if ui.get("a") else audio["sink"]}
        elif knob == "a" and op == "press":
            ui = {} if ui.get("lock") else {"a": ui.get("a") or audio["sink"], "lock": True}
        elif knob == "b" and op in ("left", "right") and ui.get("lock"):
            ui["b"] = step(devs, ui.get("b"), op, skip=ui["a"])
        elif knob == "b" and op == "press" and ui.get("lock") and ui.get("b"):
            names = {d["name"] for d in devs}
            pair = [ui["a"], ui["b"]]
            if pair in mirrors:
                mirrors.remove(pair)
                unlink_mirror(audio, *pair)
            elif pair[0] in names and pair[1] in names and not reaches(mirrors, pair[1], pair[0]):
                mirrors.append(pair)
                for src, dst in mirror_pairs(*pair):
                    sh(PW_LINK, src, dst)
            else:
                return  # would loop: keep the picks so the strip still says LOOP
            write_json(MIRRORS, mirrors)
            ui = {}
        elif knob == "m" and op in ("left", "right") and mirrors:
            m = ui.get("m")
            m = (0 if op == "right" else len(mirrors) - 1) if m is None else m + (1 if op == "right" else -1)
            ui = {"m": m} if 0 <= m < len(mirrors) else {}
        elif knob == "m" and op == "press" and ui.get("m") is not None and ui["m"] < len(mirrors):
            pair = mirrors.pop(ui["m"])
            unlink_mirror(audio, *pair)
            write_json(MIRRORS, mirrors)
            ui = {}
        write_json(AUDIO_UI, {**ui, "t": time.time()})

    elif mode == "dev" and len(argv) == 4:  # page 3 mid knobs: volume of the A / B pick
        ui = read_ui()
        name = ui.get(argv[2])
        if name and name in {d["name"] for d in devices(audio)}:
            op = argv[3]
            if op == "up":
                dev = next(d for d in devices(audio) if d["name"] == name)
                sh(PACTL, "set-sink-volume", name, f"{min(100, round(dev['vol']) + STEP)}%")
            elif op == "down":
                sh(PACTL, "set-sink-volume", name, f"-{STEP}%")
            elif op == "mute":
                sh(PACTL, "set-sink-mute", name, "toggle")
            write_json(AUDIO_UI, {**ui, "t": time.time()})

    elif mode == "grid" and len(argv) == 3:  # page through windows, 12 at a time
        op = argv[2]
        page = read_int(GRID)
        page = 0 if op == "first" else max(0, page + (1 if op == "next" else -1))
        write_text(GRID, str(page))  # publish() clamps to the real page count

    elif mode == "hud" and len(argv) == 3:  # MangoHud layout / visibility
        preset, hidden = mh_read()
        op = argv[2]
        if op == "toggle":
            hidden = not hidden
        elif op in ("next", "prev"):
            i = MH_PRESETS.index(preset) + (1 if op == "next" else -1)
            preset, hidden = MH_PRESETS[i % len(MH_PRESETS)], False
        mh_write(preset, hidden)

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

    else:
        print(__doc__, file=sys.stderr)
        sys.exit(2)

    # Show the result at once (the feed would catch up within a cycle anyway).
    publish(comp, audio_snapshot(), force=True)


if __name__ == "__main__":
    main(sys.argv)
