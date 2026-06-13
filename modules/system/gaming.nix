# Gaming: GameMode, declarative Proton-GE, and AMD GPU control/monitoring.
# GPU is RDNA4 (Radeon RX 9070 XT / Navi 48); the Vulkan driver is RADV from
# Mesa (do NOT add amdvlk — RADV is the better path for gaming). Steam itself is
# enabled in ./programs.nix; the option below merges into that config.
{ config, lib, pkgs, ... }:
{
  # Feral GameMode: while a game requests it, pins the CPU governor to
  # performance and the GPU to its high-power profile. Opt in per game with
  # `gamemoderun %command%` in Steam launch options.
  programs.gamemode.enable = true;

  # Manage Proton-GE through the flake instead of protonup-ng, so it's
  # reproducible across rebuilds. Pick it in Steam's per-game compatibility menu.
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin ];

  # LACT: AMD GPU control (fan curves, power/clock limits) and monitoring,
  # including visibility into GPU resets. Runs the lactd daemon.
  services.lact.enable = true;

  # Overlay + tooling: mangohud (FPS / frametime / VRAM / temp overlay) and
  # goverlay (its config GUI). Use with `mangohud %command%` or MANGOHUD=1.
  environment.systemPackages = with pkgs; [
    mangohud
    goverlay
  ];
}
