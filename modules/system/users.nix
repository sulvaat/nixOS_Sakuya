# User accounts.
{ config, lib, pkgs, ... }:
{
  users.users.sul = {
    isNormalUser = true;
    # `input`: lets official Discord read /dev/input/event* via evdev for global
    # keybinds (push-to-talk) — Wayland blocks apps from reading the keyboard
    # while unfocused, and Discord's evdev fallback needs this group or the key
    # never registers. (Trade-off: any process you run can then read all input.)
    extraGroups = [ "wheel" "libvirtd" "adbusers" "input" ]; # Enable 'sudo' for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
      unzip
    ];
  };
}
