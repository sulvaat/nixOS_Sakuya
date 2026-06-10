# User accounts.
{ config, lib, pkgs, ... }:
{
  users.users.sul = {
    isNormalUser = true;
    extraGroups = [ "wheel" "libvirtd" "adbusers" "openrazer" ]; # Enable 'sudo' for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
      unzip
    ];
  };
}
