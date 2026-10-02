# Audio via PipeWire (with PulseAudio compatibility).
{ config, lib, pkgs, ... }:
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;

    # AirPlay (RAOP) output: auto-discover AirPlay receivers on the LAN via
    # Avahi/mDNS (enabled in networking.nix) and expose each one as a normal
    # PipeWire output device. The Sonos Arc and Beam advertise AirPlay 2 with
    # unencrypted RAOP (et=0), so they show up as sinks you can pick in the
    # volume menu / pavucontrol. AirPlay buffers ~2 s, fine for music, not for
    # games or lip-synced video. If audio drops out or crackles, raise
    # "raop.latency.ms" in the args below.
    raopOpenFirewall = true; # UDP 6001-6002 (AirPlay timing/control)
    extraConfig.pipewire."10-airplay" = {
      "context.modules" = [
        { name = "libpipewire-module-raop-discover"; }
      ];
    };
  };
}
