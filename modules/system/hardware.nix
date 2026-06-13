# Hardware: GPU, peripherals, controllers.
{ config, lib, pkgs, ... }:
{
  # OpenRazer (Razer peripherals)
  hardware.openrazer.enable = true;

  # Graphics (AMD RDNA4 / Navi 48), with 32-bit support for games. The Vulkan
  # driver is RADV (shipped with Mesa) — no extraPackages needed. Intentionally
  # NOT using amdvlk: RADV is the faster, better-supported path for gaming.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # PS5 controller support (USB).
  hardware.steam-hardware.enable = true;
}
