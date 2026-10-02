# Virtualization / KVM.
{ config, lib, pkgs, ... }:
{
  virtualisation.libvirtd.enable = true;
  # Software TPM 2.0 emulator (swtpm) for guests — needed for Windows 11 and
  # anything using measured boot / BitLocker. UEFI + Secure Boot firmware
  # (edk2/OVMF) already ships with QEMU, so no separate OVMF option is needed.
  virtualisation.libvirtd.qemu.swtpm.enable = true;
  programs.virt-manager.enable = true;
}
