# Desktop: Xorg, Niri (Wayland), portals, compositor, fonts.
{ config, lib, pkgs, ... }:
{
  # X11 windowing system (AMD).
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
  };

  # Input devices (renamed out of services.xserver in newer nixpkgs).
  services.libinput = {
    enable = true;
    mouse = {
      middleEmulation = false;
    };
  };

  # Niri (Wayland compositor). User config lives in modules/home/niri.nix.
  programs.niri.enable = true;
  programs.dconf.enable = true;

  # Compositor for X11 apps.
  services.picom = {
    enable = true;
    backend = "glx";
    fade = true;
  };

  # XDG desktop portals.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  environment.sessionVariables = {
    #WLR_NO_HARDWARE_CURSORS = "1";
    NIXOS_OZONE_WL = "1";
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # Remove nano (enabled by default in NixOS); nvim is the editor.
  programs.nano.enable = false;

  # System fonts.
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    ipafont
  ];
}
