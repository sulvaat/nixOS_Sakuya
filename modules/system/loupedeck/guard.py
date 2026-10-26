"""Keep the Loupedeck connected to Companion.

1. Lock the port. Any program running as a session leader (Steam's Proton
   sandbox is one; Proton maps every /dev/ttyACM* to a COM port when it sets
   up a prefix) that opens the port without O_NOCTTY makes it its controlling
   terminal, and when that program exits the kernel hangs the port up for
   everyone: Companion logs "Connection lost" and the panel freezes. Once
   Companion has the port open, set TIOCEXCL on it so every other open fails
   with EBUSY. The kernel clears the flag when Companion closes the port.
2. Reconnect. Companion only scans on USB plug events, so a panel that drops
   for any other reason stays dead until a replug. If the panel is plugged in
   but Companion hasn't held it for GRACE seconds, ask Companion to rescan.
"""
import fcntl
import glob
import os
import time
import urllib.request

PERIOD = 2
GRACE = 10             # panel present but not held this long -> rescan
RESCAN_EVERY = 30      # minimum gap between rescans
RESCAN_URL = "http://127.0.0.1:8000/api/surfaces/rescan"
TIOCEXCL = 0x540C

# This service's cgroup is .../app.slice/loupedeck-guard.service; Companion's
# is its sibling.
with open("/proc/self/cgroup") as f:
    own = f.read().strip().split("::", 1)[1]
COMPANION = f"/sys/fs/cgroup{os.path.dirname(own)}/bitfocus-companion.service/cgroup.procs"


def panel():
    paths = glob.glob("/dev/serial/by-id/usb-Loupedeck_*")
    return os.path.realpath(paths[0]) if paths else None


def held_by_companion(dev):
    try:
        with open(COMPANION) as f:
            pids = f.read().split()
    except OSError:
        return False
    for pid in pids:
        try:
            fds = os.listdir(f"/proc/{pid}/fd")
        except OSError:
            continue
        for fd in fds:
            try:
                if os.readlink(f"/proc/{pid}/fd/{fd}") == dev:
                    return True
            except OSError:
                pass
    return False


def lock(dev):
    """Set TIOCEXCL; returns True if newly set, False if it already was."""
    try:
        fd = os.open(dev, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    except OSError:
        return False  # EBUSY: already exclusive (or the panel just went away)
    try:
        fcntl.ioctl(fd, TIOCEXCL)
        return True
    finally:
        os.close(fd)


def rescan():
    try:
        req = urllib.request.Request(RESCAN_URL, method="POST")
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.read().decode()
    except OSError as e:
        return str(e)


def main():
    lost_since, last_rescan = None, 0.0
    while True:
        dev = panel()
        if dev and held_by_companion(dev):
            lost_since = None
            if lock(dev):
                print(f"{dev}: locked to Companion", flush=True)
        elif dev:
            now = time.time()
            lost_since = lost_since or now
            if now - lost_since >= GRACE and now - last_rescan >= RESCAN_EVERY:
                print(f"{dev}: not held by Companion for {now - lost_since:.0f} s, rescan: {rescan()}",
                      flush=True)
                last_rescan = now
        else:
            lost_since = None
        time.sleep(PERIOD)


main()
