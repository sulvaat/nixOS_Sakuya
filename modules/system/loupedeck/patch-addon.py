"""Patch Companion's Loupedeck surface add-on before Companion starts.

Companion installs the add-on itself (~/.config/companion-nodejs/surfaces/
loupedeck-<version>/main.js), so it can't be patched in the Nix store. Run as
ExecStartPre; idempotent (a marker comment), keeps main.js.orig, and only warns
(never blocks Companion) if an add-on update changed the code being patched.

1. Handshake after a previous session. The Live never resets its WebSocket
   session when the serial port closes, so after Companion restarts (or a
   session ends mid-draw) the next HTTP upgrade request is swallowed as frame
   data and the panel stays black until it is power-cycled. Writing 256 KB of
   zeros first completes any half-received frame and drops it back to HTTP
   mode; the handshake is then answered at once. Input is flushed so the
   handshake reply isn't confused with leftovers.
2. Failed handshakes leaked the port (left open and locked), so every later
   attempt failed until a replug. Close it on failure.
3. Every draw waits for the device's ack with no timeout, so one lost ack froze
   the panel for good (draws queued until the add-on used GBs of RAM). Give
   up on an ack after 15 s (a full-screen clear right after power-up can take
   ~8 s), so the queue keeps moving.
"""
import glob
import os
import sys

MARKER = "/*sakuya-loupedeck-patch-1*/"

PATCHES = [
    # 1 + 2: flush the device's frame parser before the handshake; close on failure.
    (
        'static async open(e){let t=new pt.SerialPort({path:e,baudRate:256e3,autoOpen:!1});'
        'return await new Promise((s,i)=>{t.open(n=>{n?i(n):s()})}),'
        'await new Promise((s,i)=>{t.once("data",n=>{n.toString().startsWith(yr)?s():'
        'i(new Error(`Invalid handshake response: ${n.toString()}`))}),t.write(mr),'
        'setTimeout(()=>{i(new Error("Timed out"))},5e3)}),new r(t)}',

        'static async open(e){let t=new pt.SerialPort({path:e,baudRate:256e3,autoOpen:!1});'
        'await new Promise((s,i)=>{t.open(n=>{n?i(n):s()})});'
        'try{await new Promise(s=>t.write(Buffer.alloc(262144),()=>t.drain(()=>setTimeout(s,1e3))));'
        'await new Promise(s=>t.flush(()=>s()));'
        'await new Promise((s,i)=>{t.once("data",n=>{n.toString().startsWith(yr)?s():'
        'i(new Error(`Invalid handshake response: ${n.toString()}`))}),t.write(mr),'
        'setTimeout(()=>{i(new Error("Timed out"))},5e3)})}'
        'catch(n){t.isOpen&&t.close();throw n}return new r(t)}',
    ),
    # 3: time out a missing ack instead of waiting forever.
    (
        'return this.#o[e]=t,s}',

        'this.#o[e]=t;let o=setTimeout(()=>{this.#o[e]===t&&(delete this.#o[e],'
        't.reject(new Error("No ack from Loupedeck in 15 s")))},15e3);'
        'return s.finally(()=>clearTimeout(o))}',
    ),
]


def patch(path):
    with open(path) as f:
        src = f.read()
    if MARKER in src:
        return f"{path}: already patched"
    missing = [i + 1 for i, (old, _) in enumerate(PATCHES) if src.count(old) != 1]
    if missing:
        return (f"{path}: WARNING add-on code changed (patch {missing} not found); "
                "left unpatched - see modules/system/loupedeck/patch-addon.py")
    for old, new in PATCHES:
        src = src.replace(old, new)
    if not os.path.exists(path + ".orig"):
        os.link(path, path + ".orig")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(MARKER + "\n" + src)
    os.replace(tmp, path)
    return f"{path}: patched"


paths = glob.glob(os.path.expanduser("~/.config/companion-nodejs/surfaces/loupedeck-*/main.js"))
if not paths:
    print("no Loupedeck add-on installed yet (install it in Companion, then restart)")
for p in paths:
    try:
        print(patch(p))
    except Exception as e:  # never block Companion from starting
        print(f"{p}: patch failed: {e}", file=sys.stderr)
