# Hardware: GPU, peripherals, controllers.
{ config, lib, pkgs, ... }:
{
  # OpenRazer (Razer peripherals)
  hardware.openrazer.enable = true;

  # Graphics (AMD), with 32-bit support for games.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  #hardware.graphics.extraPackages = with pkgs; [
  #  radv
  #];
  # For 32-bit applications
  #hardware.graphics.extraPackages32 = with pkgs; [
  #  driversi686Linux.amdvlk
  #];

  # PS5 controller support (USB).
  hardware.steam-hardware.enable = true;
}
