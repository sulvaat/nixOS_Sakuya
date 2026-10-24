# Loupedeck Live on Sakuya — quick manual

The Loupedeck Live is driven by **Bitfocus Companion** (Loupedeck ships no Linux
software). Two small helpers feed it live data: audio levels for the VU meters,
and niri windows / audio / MangoHud state for everything else.

- Companion admin UI: <http://127.0.0.1:8000> (Fuzzel → **Companion**). Localhost only.
- Nix config: [`modules/system/loupedeck.nix`](../../modules/system/loupedeck.nix)
- Window/audio helper: [`modules/system/loupedeck/niri-deck.py`](../../modules/system/loupedeck/niri-deck.py)
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

### Page 1 — windows & audio

| Control | Turn | Press / tap |
|---|---|---|
| **Touch grid** (12 windows) | — | **tap:** mute/unmute that window's audio · **hold ½ s:** open page 2 for that window |
| **Strips** | — | left = L channel, right = R channel VU meter (green → yellow → red) |
| Knob **left top** (0/0) | master volume ±2% | mute master |
| Knob **left mid** (1/0) | mic gain ±2% | mute mic |
| Knob **left bot** (2/0) | seek ±5 s | play / pause |
| Knob **right top** (0/7) | page the window grid (12 per page) | back to first page |
| Knob **right mid** (1/7) | MangoHud layout (preset 1–4) | show / hide MangoHud |
| Knob **right bot** (2/7) | previous / next track | restart track |

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
| left mid / bot | mic / seek (same as page 1) | |
| **right top** | window width ±5% | maximize |
| **right mid** | move column left / right | center |
| **right bot** | move to workspace up / down | toggle floating |

### Round-button LEDs

| Button | Page 1 | Page 2 |
|---|---|---|
| 3/0 | master level | **selected app** level (off if it has no audio) |
| 3/1 | mic level | mic level |
| 3/2 | song position | song position |
| 3/5 | blue = more windows than fit on one page | |
| 3/6 | MangoHud: 🟢 FPS only · 🔵 horizontal · 🟡 extended · 🟣 detailed · off = hidden | |

- **Level LEDs:** green at 100% → yellow → red at 0%. **Muted = blinking red.**
- **Song position:** green at the start → red at the end; dimmed while paused; off with no player.

## How it works

| Piece | What it does |
|---|---|
| `bitfocus-companion` (user service) | Companion server, `--admin-address 127.0.0.1 --enable-shell-command-support`, starts with the session |
| `companion-vu-feed` (user service) | Records the default output's monitor, peak per channel (−48 dB…0 dB → 0–100) → `vu_l` / `vu_r` |
| `niri-deck-feed` (user service) | Every 0.4 s publishes `niri`, `niri_sel`, `deck` (see below) |
| `niri-deck` (command) | Run by buttons/knobs: `/run/current-system/sw/bin/niri-deck …` |
| udev rule `70-loupedeck.rules` | Gives the logged-in user access to Loupedeck devices (`uaccess`), tells ModemManager to ignore them |
| `/usr/bin/udevadm` symlink | Companion's add-ons run with no `PATH`; the Loupedeck add-on needs `udevadm` to find the device |
| Patched Companion (open timeout 30 s) | Companion allows 5 s to open a surface; after power-up the Live takes ~5-9 s to clear its displays, so stock Companion gave up and the panel stayed dark |

Companion custom variables (all must exist, or the feeds log a 404):

| Variable | Contents |
|---|---|
| `vu_l`, `vu_r` | VU levels 0–100 |
| `niri` | JSON list of 12 slots `{id, t title, a app, s audio, f focused, b bg colour, c dot colour}` |
| `niri_sel` | JSON of the held window `{id, t, a, o output, vol}` |
| `deck` | JSON `{vol, vm, mic, mm, lv, lm, la, lf, lg, gp, lh}` — levels, mute flags, LED colours |

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
```

Tunables live at the top of `niri-deck.py` (`STEP`, `SEEK`, colours, `PERIOD`)
and in `vuFeed` inside `loupedeck.nix` (meter floor / release).

## Restore from scratch

1. `rb` (installs everything, starts the services at next login — or
   `systemctl --user start bitfocus-companion companion-vu-feed niri-deck-feed`).
2. Open Companion → **Import / Export** → import `docs/loupedeck/companion-config.companionconfig`
   (pages 1–2 and the custom variables).
3. **Surfaces** → **Rescan USB** → enable the Loupedeck Live and set
   **LCD strip mode = Split buttons** (surface settings aren't in the backup; they're
   keyed by the device serial).

Re-export after changing buttons: Companion → Import / Export → Export (exclude secrets),
or `curl -s 'http://127.0.0.1:8000/int/export/full?includeSecrets=false&format=json'`
— then drop the `surfaces` section before committing.

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

## Troubleshooting

| Symptom | Check |
|---|---|
| "No surfaces found" | `journalctl --user -u bitfocus-companion` — `spawn udevadm ENOENT` means the `/usr/bin/udevadm` symlink is missing; permission errors → replug after `rb` (`ls -l /dev/ttyACM*` should show `+`) |
| Panel shows its logo, then goes dark; log says `Call timed out` then `already opened` | the open-timeout patch isn't active: `systemctl --user cat bitfocus-companion` should show a `…-loupedeck` store path. If the build failed at `substituteInPlace`, a Companion update changed the code: check whether upstream fixed it, else update the patch string in `loupedeck.nix`. To recover now: `systemctl --user restart bitfocus-companion`, then replug |
| Meters / windows / LEDs frozen | `systemctl --user status companion-vu-feed niri-deck-feed`; their logs name any missing custom variable |
| A button shows `ERR` | the expression returned nothing — see Gotchas |
| MangoHud knob does nothing | game must run with `mangohud` / `--mangoapp`; remove `MANGOHUD_CONFIG=` from launch options; restart the game once so MangoHud watches the config |
| Yellow "USB permissions" banner in Companion | harmless on NixOS (`/etc` is read-only); access comes from `70-loupedeck.rules` |
