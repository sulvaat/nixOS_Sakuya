# Gaming: GameMode, declarative Proton-GE, and AMD GPU control/monitoring.
# GPU is RDNA4 (Radeon RX 9070 XT / Navi 48); the Vulkan driver is RADV from
# Mesa (do NOT add amdvlk — RADV is the better path for gaming). Steam itself is
# enabled in ./programs.nix; the option below merges into that config.
{ config, lib, pkgs, ... }:
let
  # Force the AMD GPU to its high performance level for the lifetime of a game,
  # restoring `auto` on exit. amdgpu's `auto` governor stops boosting
  # mid-session on this RX 9070 XT and parks the card at ~1400 MHz / ~96 W /
  # 55 C with load ~67% — a stuck P-state that permanently tanks FPS (even in
  # menus) until the game restarts, despite ample power/thermal headroom.
  # `high` pins max clocks and overrides the governor so the stall can't happen.
  #
  # This runs entirely as the user: the udev rule below makes the sysfs knob
  # group-writable, so no root/polkit is involved. GameMode can't do this here —
  # it elevates gpuclockctl via pkexec and NixOS ships no polkit authorization
  # for its helpers, so every privileged GameMode action is denied ("Not
  # authorized"), leaving the level on `auto`. Hence this direct wrapper.
  #
  # Wrap the WHOLE launch command in Steam options, e.g.:
  #   RADV_DEBUG=nodcc gpu-perf gamescope -W 5120 -H 1440 -r 120 -f --force-grab-cursor --mangoapp -- %command%
  gpuPerf = pkgs.writeShellScriptBin "gpu-perf" ''
    ppl=/sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level
    restore() { echo auto > "$ppl" 2>/dev/null || true; }
    trap restore EXIT INT TERM
    echo high > "$ppl" 2>/dev/null || true
    "$@"
  '';
in
{
  # Feral GameMode: pins the CPU governor / renices while a game runs. Opt in per
  # game with `gamemoderun %command%`. NOTE: its CPU/GPU/split-lock optimisations
  # need polkit authorization for pkexec, which NixOS doesn't set up, so those
  # privileged tweaks are denied here — GPU clocks are handled by gpu-perf below
  # instead. Left enabled for the parts that work and for future use.
  programs.gamemode.enable = true;

  # Make /sys/.../power_dpm_force_performance_level group-writable by `users` so
  # the gpu-perf wrapper (above) can set `high`/`auto` without root. Matched by
  # driver so it's independent of the card index; ACTION=="add|change" so a live
  # `udevadm trigger` (which sends `change`) applies it too, not just boot.
  # %S = /sys, %p = the drm device's devpath.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card*", DRIVERS=="amdgpu", RUN+="${pkgs.coreutils}/bin/chgrp users %S%p/device/power_dpm_force_performance_level", RUN+="${pkgs.coreutils}/bin/chmod g+w %S%p/device/power_dpm_force_performance_level"
  '';

  # Manage Proton-GE through the flake instead of protonup-ng, so it's
  # reproducible across rebuilds. Pick it in Steam's per-game compatibility menu.
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  # Gamescope: a nested Wayland/Xwayland micro-compositor. Halo Infinite launches
  # its campaign as a separate "subgame" process (HaloInfinite.exe -subgame
  # CampaignS1); on niri/wlroots that second window never registers with
  # xwayland-satellite, so it's audible but invisible. Running the game inside
  # gamescope hosts all of Halo's windows (including the subgame relaunch) in a
  # single window niri manages. Enable per game via Steam launch options, e.g.:
  #   RADV_DEBUG=nodcc gpu-perf gamescope -W 5120 -H 1440 -r 120 -f --force-grab-cursor --mangoapp -- %command%
  # (RADV_DEBUG=nodcc avoids DCC corruption artifacting on RDNA4; gpu-perf pins
  # GPU clocks — see above.) `programs.gamescope.enable` installs it with the
  # CAP_SYS_NICE capability it needs for realtime scheduling.
  programs.gamescope.enable = true;

  # RADV from Mesa main (via chaotic-nyx). Stable Mesa lacks the descriptor-
  # heap fix (Mesa MR !41680) that Forza Horizon 6 needs on RDNA4: without it,
  # `RADV_EXPERIMENTAL=heap` enables the heap path but the driver renders it
  # wrong, producing periodic full-screen smearing. Prebuilt by the chaotic
  # binary cache (auto-configured by chaotic.nixosModules.default), so this
  # does not compile Mesa from source.
  chaotic.mesa-git.enable = true;

  # LACT: AMD GPU control (fan curves, power/clock limits) and monitoring,
  # including visibility into GPU resets. Runs the lactd daemon.
  services.lact.enable = true;

  # Overlay + tooling: mangohud (FPS / frametime / VRAM / temp overlay) and
  # goverlay (its config GUI). Use with `mangohud %command%` or MANGOHUD=1.
  environment.systemPackages = with pkgs; [
    mangohud
    goverlay
    gpuPerf   # `gpu-perf`: pin GPU to high perf level for a wrapped game (see above)
  ];
}
