# Bootloader and kernel.
{ config, lib, pkgs, ... }:
{
  # systemd-boot (EFI)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use the latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;
  #boot.kernelPackages = pkgs.linuxKernel.packages.linux_7_0;

  # Load the AMD GPU module early.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # AMD GPU multi-monitor video modes (disabled)
  #boot.kernelParams = [
  #  "video=DP-1:5120x1440@120"
  #  "video=DP-2:1440x2560@144"
  #];
}
