# Audio via PipeWire (with PulseAudio compatibility).
{ config, lib, pkgs, ... }:
{
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };
}
