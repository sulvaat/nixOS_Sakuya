# Loupedeck Live on Sakuya — quick manual

The Loupedeck Live is driven by **Bitfocus Companion** (Loupedeck ships no Linux
software). One helper, `niri-deck`, feeds it live data (niri windows, audio
devices and streams, media, MangoHud) and runs the actions behind the buttons
and knobs.

- Companion admin UI: <http://127.0.0.1:8000> (Fuzzel → **Companion**). Localhost only.
- Nix config: [`modules/system/loupedeck.nix`](../../modules/system/loupedeck.nix)
- Deck helper: [`modules/system/loupedeck/niri-deck.py`](../../modules/system/loupedeck/niri-deck.py)
- Companion config backup: [`companion-config.companionconfig`](companion-config.companionconfig)

## Layout

Companion addresses the Live as a grid (rows/columns from 0):

```
          col0    col1      col2 – col5      col6      col7
row 0     knob  [L strip]   touch grid    [R strip]    knob
row 1     knob  [L strip]   touch grid    [R strip]    knob
row 2     knob  [L strip]   touch grid    [R strip]    knob
row 3     ─────────── 8 round buttons (RGB LEDs), cols 0–7 ───────────
```

Each **strip cell** is a readout for the knob beside it: a label, the value,
and a bar where it fits (levels fade green at 100% → red at 0%; solid red
"MUTE" when muted). The **bottom-left knob is media on every page** (turn =
seek ±5 s, press = play / pause); it never changes audio devices.

| Page | Opened by | What it's for |
|---|---|---|
| 1 | start page | windows & audio |
| 2 | hold a window ½ s on page 1 | the held window |
| 3 | round button 3/3 on page 1 | system output, mirrors |
| 4 | round button 3/3 on page 2 | the held window's output |

### Page 1 — windows & audio

| Control | Turn | Press / tap |
|---|---|---|
| **Touch grid** (12 windows) | — | **tap:** mute/unmute that window's audio · **hold ½ s:** page 2 for that window |
| Knob **left top** (0/0) | master volume ±2% | mute master |
| Knob **left mid** (1/0) | mic gain ±2% | mute mic |
| Knob **left bot** (2/0) | seek ±5 s | play / pause |
| Knob **right top** (0/7) | page the window grid (12 per page) | back to first page |
| Knob **right mid** (1/7) | MangoHud layout (preset 1–4) | show / hide MangoHud |
| Knob **right bot** (2/7) | previous / next track | restart track |

Strips: **VOL · MIC · PLAY** (position m:ss, bar = song progress) | **GRID**
(page/pages) · **HUD** (preset name in its LED colour, or OFF) · **TRACK** (title).

Window buttons show title, app, a dot (🟢 playing · 🔴 muted · ⚪ paused) and a
dark-blue background on the focused window. Windows are ordered left→right by
monitor (DP-1, DP-2, HDMI-A-1), then on-screen position.

### Page 2 — the held window

| | col 2 | col 3 | col 4 | col 5 |
|---|---|---|---|---|
| **row 0** | title (tap = focus) | Float | Fullscreen | Close |
| **row 1** | 33% | 50% | 66% | Maximize |
| **row 2** | → Ultrawide (DP-1) | → Vertical (DP-2) | → HDMI | ◀ Back |

| Knob | Turn | Press |
|---|---|---|
| **left top** | **this window's** volume ±2% | mute this window |
| left mid / bot | mic / media (same as page 1) | |
| **right top** | window width ±5% | maximize |
| **right mid** | move column left / right | center |
| **right bot** | move to workspace up / down | toggle floating |

Strips: **app** (its name and volume, "-" without audio) · MIC · PLAY |
**WIDTH** (% of the monitor; FLOAT if floating) · **COLUMN** (n/columns) ·
**WS** (output and workspace number).

### Page 3 — audio outputs and mirrors

The touch grid is a board of every output device that's present (up to 12):

```
┌─────────────┐   colour bar: the device's colour (also its 3/3 LED colour)
│▀▀▀▀▀▀▀▀▀▀▀▀▀│
│ TEAC UD-301 │   full device name (HDMI outputs: the monitor's name)
│   SYSTEM    │   SYSTEM = system output · + MIRROR = copy of another device
│Google Chrome│     (in that device's colour) · AIRPLAY = Sonos
└─────────────┘   apps playing there
```

**Tap a device** to make it the system output (the deck returns to page 1).
Apps follow the system output unless pinned on page 4.

The list is live: a device that appears (plugged in, or JamesDSP's sink while
it runs) takes the next free key and keeps its colour from then on. The first
devices got fixed colours: TEAC white, S/PDIF orange, Speakers green,
Headphones cyan, MV7 yellow, TASCAM pink, HDMI purple, Arc blue, Beam light
blue. Red is reserved for a locked mirror source.

**Mirroring** (play one device's audio on another as well, like dragging its
monitor to another device in Helvum). Nothing changes until both ends are
confirmed:

| Knob | Turn | Press |
|---|---|---|
| **left top** | pick source **A** (white frame; starts at the system output) | **lock A** (red background); press again to cancel |
| **right top** | pick target **B** (white frame) | **confirm**: adds A → B, or removes it if it exists |
| left mid / right mid | volume of A / B ±2% | mute A / B |
| left bot | media | play / pause |
| **right bot** | step through saved mirrors | delete the one shown |

Strips: **PICK A / A LOCKED** (name in its colour) · **A VOL** · PLAY |
**B · ADD / B · REMOVE / B · LOOP** · **B VOL** · **MIRRORS** (count, or
"MIRROR 1/2 · DEL" with "A → B" while stepping). A pick that would create a loop
(B already flows back to A) shows LOOP and confirming does nothing. Picks clear
after 60 s untouched.

Mirrors are saved and re-linked whenever both devices are present (after a
reboot, a replug, a PipeWire restart). B keeps its own volume. AirPlay devices
lag local ones by a quarter second or more, so mirroring a local device to the
Sonos in the same room sounds doubled.

### Page 4 — the held window's output

The same device board; the device the held window's audio is on has a white
frame and reads **PINNED** or **VIA SYSTEM**.

- **Tap a device:** pin the app there (it stays there when the system output
  changes). Tap the device it's pinned to again to un-pin. Back to page 2.
- Knob **right bot** press: un-pin (follow the system output).
- Left knobs: app volume, mic, media (as on page 2).

Strips: app · MIC · PLAY | **OUTPUT FOR** (app) · **NOW ON** (device, in its
colour) · **PINNED / FOLLOWS SYSTEM**.

Pins are WirePlumber's per-app stream targets, so they're remembered per app
(all of its windows) across restarts. A window with no audio shows "no audio"
and taps do nothing.

### Round buttons

| Button | Page 1 | Page 2 | Page 3 | Page 4 |
|---|---|---|---|---|
| 3/0 | master level · press: mute | ◀ back to 1 (red) | ◀ back to 1 (red) | ◀ back to 2 (red) |
| 3/1 | mic level · press: mute | mic level | mic level · press: mute | mic level |
| 3/2 | song position · press: play/pause | song position | song position · press: play/pause | song position |
| 3/3 | **system output colour** · press: page 3 | **held app's output colour** (off without audio) · press: page 4 | system output colour · press: back | held app's output colour · press: back |
| 3/5 | blue = more windows than fit on one page | | | |
| 3/7 | MangoHud: 🟢 FPS only · 🔵 horizontal · 🟡 extended · 🟣 detailed · off = hidden | | | |

- **Level LEDs:** green at 100% → yellow → red at 0%. **Muted = blinking red.**
- **Song position:** green at the start → red at the end; dimmed while paused; off with no player.

## How it works

| Piece | What it does |
|---|---|
| `bitfocus-companion` (user service) | Companion server, `--admin-address 127.0.0.1 --enable-shell-command-support`, starts with the session |
| `niri-deck-feed` (user service) | Every 0.4 s publishes `niri`, `niri_sel`, `deck`, `strip`, `audio` (below); re-reads PipeWire state only when `pactl subscribe` reports a change, and re-links saved mirrors |
| `niri-deck` (command) | Run by buttons/knobs: `/run/current-system/sw/bin/niri-deck …` |
| `loupedeck-guard` (user service) | Locks the Live's serial port to Companion (`TIOCEXCL`) and rescans if the panel is plugged in but not connected for 10 s (see Troubleshooting) |
| Patched Companion (store) | Open timeout 30 s instead of 5 s (the Live needs ~5–9 s after power-up); add-ons that ask for Node 22 get it (Node 26's event loop spins on the serial port: 30–100% of a core) |
| Patched Loupedeck add-on (`patch-addon.py`) | Runs before Companion starts; the add-on lives in `~/.config/companion-nodejs/surfaces/`. Flushes the panel's stale WebSocket session before the handshake, closes the port on a failed handshake, times out lost draw acks (15 s). Keeps `main.js.orig`; only warns if an add-on update changed the code |
| udev rule `70-loupedeck.rules` | Gives the logged-in user access to Loupedeck devices (`uaccess`), tells ModemManager to ignore them |
| `/usr/bin/udevadm` symlink | Companion's add-ons run with no `PATH`; the Loupedeck add-on needs `udevadm` to find the device |

Companion custom variables (all must exist, or the feed logs a 404):

| Variable | Contents |
|---|---|
| `niri` | JSON list of 12 slots `{id, t title, a app, s audio, f focused, b bg colour, c dot colour}` |
| `niri_sel` | JSON of the held window `{id, t, a, o output, vol}` |
| `deck` | JSON `{vol, vm, mic, mm, lv, lm, la, lf, lg, gp, lh, lo, lao}` — levels, mute flags, LED colours |
| `strip` | JSON list of 24 strip cells (6 per page) `{l label, v value, f bar 0–100 or -1, c bar colour, vc value colour}` |
| `audio` | JSON list of 24 device keys (pages 3 and 4) `{n name, c colour, s status, sc status colour, p apps, bg, bw cursor border}` |

Button expressions index them by position, e.g. a strip cell uses
`jsonparse($(custom:strip))[($(this:page) - 1) * 6 + ($(this:column) == 6 ? 3 : 0) + $(this:row)]`
and a device key `jsonparse($(custom:audio))[($(this:page) - 3) * 12 + $(this:row) * 4 + $(this:column) - 2]`.

State files: `~/.local/state/niri-deck/colours.json` (device colours, in board
order; delete it to re-seed), `mirrors.json` (saved mirrors);
`$XDG_RUNTIME_DIR/niri-deck/` holds the held window, grid page and page-3 picks.

Audio is matched to windows by walking each stream's process up its parent chain
to a window's pid (browsers play audio from child processes).

### `niri-deck` commands

```
tap ROW COL | select ROW COL          window grid (Companion passes $(this:row) $(this:column))
vol|mic|app up|down|mute              master / mic / held window
media fwd|back|toggle|next|prev|restart
grid next|prev|first                  window-grid paging
hud next|prev|toggle                  MangoHud (rewrites ~/.config/MangoHud/MangoHud.conf)
act focus|close|float|fullscreen|center|maximize|colleft|colright|wsup|wsdown
act width 50% | width +5% | monitor DP-1
out system ROW COL                    page 3: make that device the system output
out app ROW COL | out follow          page 4: pin / un-pin the held window's audio
mirror a|b|m left|right|press         page 3: pick+lock A, pick+confirm B, saved mirrors
dev a|b up|down|mute                  page 3: volume of the picked A / B device
```

Tunables live at the top of `niri-deck.py` (`STEP`, `SEEK`, `PERIOD`,
`TITLE_HOLD`, colours, `KNOWN_COLOURS` / `SPARE_COLOURS`, `CURSOR_IDLE`).

## Restore from scratch

1. `rb` (installs everything, starts the services at next login — or
   `systemctl --user start bitfocus-companion niri-deck-feed loupedeck-guard`).
2. Install the Loupedeck surface add-on in Companion (**Surfaces** → add-ons),
   then `systemctl --user restart bitfocus-companion` so `patch-addon.py`
   patches it.
3. Open Companion → **Import / Export** → import `docs/loupedeck/companion-config.companionconfig`
   (pages 1–4 and the custom variables).
4. **Surfaces** → **Rescan USB** → enable the Loupedeck Live and set
   **LCD strip mode = Split buttons** (surface settings aren't in the backup; they're
   keyed by the device serial).

Re-export after changing buttons: Companion → Import / Export → Export (exclude secrets),
or `curl -s 'http://127.0.0.1:8000/int/export/full?includeSecrets=false&format=json'`
— then empty the `surfaces` section before committing.

## Gotchas (read before editing buttons)

- **`+` does not join strings** in Companion expressions (`'a' + 'b'` → `null`). Index
  JSON instead: `jsonparse($(custom:niri))[$(this:row) * 4 + $(this:column) - 2].t`.
- **Local variables (`$(local:…)`) didn't resolve in element styles** here — inline the lookup.
- **Text Size is a % of the element's height**; use ~30 with *Shrink to fit* for titles.
- **A round button's LED colour = its Background box colour** (Color expression).
- Shell-command actions need the **full path** `/run/current-system/sw/bin/niri-deck`.
- Knob turns need **Options → Rotary actions**.
- Test an expression against the live engine with Companion's preview API
  (`preview.expressionStream.watchExpression` over `ws://127.0.0.1:8000/trpc`).
- Whole pages can be built from a page-export JSON and imported over tRPC
  (`importExport.prepareImport.start` / `uploadChunk` / `complete`, then
  `importExport.importSinglePage` with `targetPage: -1`); that's how pages 3–4
  were made from page 1–2 controls as templates.

## Troubleshooting

| Symptom | Check |
|---|---|
| "No surfaces found" | `journalctl --user -u bitfocus-companion` — `spawn udevadm ENOENT` means the `/usr/bin/udevadm` symlink is missing; permission errors → replug after `rb` (`ls -l /dev/ttyACM*` should show `+`) |
| Panel shows its logo, then goes dark; log says `Call timed out` then `already opened` | the open-timeout patch isn't active: `systemctl --user cat bitfocus-companion` should show a `…-loupedeck` store path. If the build failed at `substituteInPlace`, a Companion update changed the code: check whether upstream fixed it, else update the patch string in `loupedeck.nix`. To recover now: `systemctl --user restart bitfocus-companion`, then replug |
| Panel stays black after Companion restarts | the add-on patch isn't applied: the Companion log starts with `…/main.js: patched` / `already patched`, or a WARNING that an add-on update changed the code (update `patch-addon.py`). A power-cycle (replug) recovers the panel |
| Panel froze; log says `Connection lost` with no USB unplug | something else opened the port and hung it up (Proton does when it builds a prefix). `loupedeck-guard` should prevent it and rescan within ~10 s: `journalctl --user -u loupedeck-guard` shows `locked to Companion` after each connect. Manual rescan: `curl -X POST http://127.0.0.1:8000/api/surfaces/rescan` |
| Companion (or a `node` child) uses lots of CPU while idle | the add-on is on Node 26: `ls -l /proc/<pid>/exe` for the surface child should show `nodejs-slim-22`; if the build failed at "getNodeJsPath patch target not found", a Companion update changed that code |
| Readouts / windows / LEDs / device board frozen | `systemctl --user status niri-deck-feed`; its log names any missing custom variable |
| A mirror didn't come back | both devices must be present; `pw-link -l` shows the links. `~/.local/state/niri-deck/mirrors.json` lists what's saved; turning page 3's right-bottom knob steps through them |
| An app ignores system-output changes | it's pinned: page 4 shows PINNED; press the right-bottom knob there (or tap its device) to un-pin |
| A button shows `ERR` | the expression returned nothing — see Gotchas |
| MangoHud knob does nothing | game must run with `mangohud` / `--mangoapp`; remove `MANGOHUD_CONFIG=` from launch options; restart the game once so MangoHud watches the config |
| Yellow "USB permissions" banner in Companion | harmless on NixOS (`/etc` is read-only); access comes from `70-loupedeck.rules` |
