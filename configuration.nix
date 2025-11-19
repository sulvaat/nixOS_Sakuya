# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
{

 # --- STYLIX CONFIG MOVED HERE ---
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-city-dark.yaml";
  stylix.image = ./pano.jpg;
  stylix.fonts = {
    monospace = {
      package = pkgs.nerd-fonts.jetbrains-mono;
      name = "JetBrainsMono Nerd Font";
    };
    sansSerif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Sans";
    };
    serif = {
      package = pkgs.dejavu_fonts;
      name = "DejaVu Serif";
    };
  };
  # --- END STYLIX CONFIG ---

  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];
   # Home Manager

home-manager.useUserPackages = true;
home-manager.useGlobalPkgs = true;
home-manager.backupFileExtension = "backup";
##home-manager.users.sul = import ./home.nix;
home-manager.users.sul = {
  imports = [ ./home.nix ];
};


  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # AMD GPU Multimonitor
#boot.kernelParams = [
#  "video=DP-1:5120x1440@120"
#  "video=DP-2:1440x2560@144"
#];


  # Kernel Modules
  boot.initrd.kernelModules = [ "amdgpu" ];
 
  networking.hostName = "Sakuya"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
 
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.
  networking.hosts = { "10.1.1.5" = [ "pronas" ]; };
  fileSystems."/home/sul/nfs" = { device = "pronas:/var/nfs/shared/Nihonhut"; fsType = "nfs"; options = [ "x-systemd.automount" "noauto" ]; };
  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
  # services.xserver.enable = true;
services.xserver = {
	enable = true;
	windowManager.awesome.enable = true;
	displayManager.sessionCommands = ''
	   xset r rate 185 35 &
	   '';
         videoDrivers = [ "amdgpu" ];
	 libinput = {
    enable = true;
    mouse = {
      middleEmulation = false;
    };
  };
	
};

 # Graaphics settings:
hardware.graphics = {
  enable = true;
  enable32Bit = true;
};
  
#hardware.graphics.extraPackages = with pkgs; [
#  radv
#];
# For 32 bit applications 
#hardware.graphics.extraPackages32 = with pkgs; [
#  driversi686Linux.amdvlk
#];

##hardware.opengl = {
##  enable = true;
  ##driSupport = true; No longer used? aiight.
##};


  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";
##services.xserver.videoDrivers = ["amdgpu"];
  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
 services.pipewire = {
    enable = true;
    pulse.enable = true;
 };






  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
 users.users.sul = {
   isNormalUser = true;
   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
   packages = with pkgs; [
     tree
   ];
 };
# Browsers
programs.firefox.enable = true;

# Shells
programs.fish.enable = true;

# Niri
programs.niri.enable = true;
programs.dconf.enable = true;

# Hyperland on NixOS
programs.hyprland = {
   enable = true;
   xwayland.enable = true;

};

environment.sessionVariables = {
   #WLR_NO_HARDWARE_CURSORS = "1";
   NIXOS_OZONE_WL = "1";

};

xdg.portal.enable = true;
xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];


#allow unfree
nixpkgs.config.allowUnfree = true;

# Steam
programs.steam = {
   enable = true;
   remotePlay.openFirewall = true;
   dedicatedServer.openFirewall = true;
   localNetworkGameTransfers.openFirewall = true;
};

   ## Fonts
#fonts.packages = with pkgs; [
#   jetbrains-mono
#];


#nix-env -iA nixos.themechanger; # On NixOS

## THEMES



##hardware ={
##   graphics.enable = true;
##};
# List packages installed in system profile.
# You can use https://search.nixos.org/ to find more packages (and options).
environment.systemPackages = with pkgs; [
   vim
   wget
   pciutils
   btop
   neovim
   pavucontrol
   pkgs.dunst
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
   protonup-ng
   bat
   streamcontroller
   spotify
   eza
   mesa
   tldr
   pfetch
   arandr
   autorandr
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
   polybar
   xwayland-satellite
   waypaper
   psmisc
   quodlibet
   
];

services.flatpak.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  # Enable compositor
  services.picom = {
	enable = true;
	backend = "glx";
	fade = true;

};
  ## Setup Filesystems

fileSystems."/mnt/game" = {
   device = "/dev/disk/by-uuid/5798a546-97ca-49d9-b9fc-380a7937fd10";
   fsType = "btrfs";
   options = [ # If you don't have this options attribute, it'll default to "defaults" 
     # boot options for fstab. Search up fstab mount options you can use
     "users" # Allows any user to mount and unmount
     "nofail" # Prevent system from failing if this drive doesn't mount
     
   ];
 };

 fileSystems."/mnt/game2" = {
   device = "/dev/disk/by-uuid/7dccbc2e-98ba-4c98-9d72-af7245f40e53";
   fsType = "btrfs";
   options = [ # If you don't have this options attribute, it'll default to "defaults" 
     # boot options for fstab. Search up fstab mount options you can use
     "users" # Allows any user to mount and unmount
     "nofail" # Prevent system from failing if this drive doesn't mount
     
   ];
 };

 fileSystems."/mnt/blk" = {
   device = "/dev/disk/by-uuid/a3080121-41d5-4223-90a7-52c038d73bba";
   fsType = "btrfs";
   options = [ # If you don't have this options attribute, it'll default to "defaults" 
     # boot options for fstab. Search up fstab mount options you can use
     "users" # Allows any user to mount and unmount
     "nofail" # Prevent system from failing if this drive doesn't mount
     
   ];
 };
## Clean up Garbage every week
nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 7d";
};

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "25.05"; # Did you read the comment?

nix.settings.experimental-features = [ "nix-command" "flakes" ];

}

