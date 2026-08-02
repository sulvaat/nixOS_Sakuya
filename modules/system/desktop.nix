# Desktop: Niri (Wayland), input, portals, fonts. Boots to a console — start the
# session from a TTY with the `desktop` command (below).
{ config, lib, pkgs, ... }:
let
  # Minimal login flow: boot to a TTY, log in, then run `desktop` to start niri.
  # Prints a figlet banner of the hostname, then hands off to niri-session
  # (which sets up the systemd user session + D-Bus). `exec` so the TTY drops
  # back to the login prompt when niri exits. Guards against launching a second
  # session from inside an existing one.
  desktopLauncher = pkgs.writeShellScriptBin "desktop" ''
    if [ -n "$WAYLAND_DISPLAY$DISPLAY" ]; then
      echo "A desktop session already looks active — not starting another." >&2
      exit 1
    fi
    ${pkgs.figlet}/bin/figlet "${config.networking.hostName}"
    echo "Starting niri…"
    exec ${config.programs.niri.package}/bin/niri-session
  '';
in
{
  # No X server and no display manager. niri is Wayland-native and X apps run
  # through xwayland-satellite, so the system X server (and the LightDM that
  # services.xserver auto-enables) are unnecessary. We boot to a plain console
  # and start the desktop by hand with `desktop`. amdgpu still loads via the
  # kernel/KMS at boot, independent of the old xserver.videoDrivers setting.
  # (The niri/wayland module still pulls in graphical-desktop.nix, which sets
  # graphical.target at normal priority, so mkForce wins us the console boot.)
  systemd.defaultUnit = lib.mkForce "multi-user.target";
  environment.systemPackages = [ pkgs.figlet desktopLauncher ];

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

  # XDG desktop portals. (Screenshots are handled directly by grim/slurp/satty
  # in the niri config, not via the Screenshot portal — flameshot v14's
  # portal-only capture never worked reliably on niri; see modules/home/niri.nix.)
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
