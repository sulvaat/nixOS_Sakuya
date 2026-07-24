# System-wide packages (environment.systemPackages).
# Find packages at https://search.nixos.org/.
{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    pciutils
    btop
    neovim
    pavucontrol
    libnotify
    xwallpaper
    nautilus
    file-roller
    vivaldi
    gedit
    mpv
    flatpak
    lutris
    discord
    rofi
    nitrogen
    parted
    bat
    ##   streamcontroller
    spotify
    eza
    mesa
    tldr
    fastfetch
    #arandr
    #autorandr
    git
    htop
    nvtopPackages.amd
    samba
    scrot
    clock-rs
    xcp
    nyaa
    rtorrent
    transmission_4
    gcc
    image-roll
    imv          # Wayland-native lightweight image viewer
    pcmanfm
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
    alacritty
    swaybg
    #polybar
    xwayland-satellite
    waypaper
    psmisc
    quodlibet
    cava
    grim
    polychromatic
    input-remapper
    python3
    python3Packages.pip    # Changed from python311Packages
    python3Packages.flask  # Changed from python311Packages
    python3Packages.rich   # Changed from python311Packages
    jamesdsp
    claude-code
    cargo
    rustc
    rustfmt
    rust-analyzer
    android-tools
    nodejs        # Provides both `node` and `npm`
    nix-tree
    darktable
    filezilla
  ];
}
