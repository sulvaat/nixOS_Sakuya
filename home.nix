{ config, pkgs, osConfig, lib, ... }:



{
  home.username = "sul";
  home.homeDirectory = "/home/sul";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  # 1. Install Niri specific packages
  home.packages = with pkgs; [
    swaybg
    xwayland-satellite
    nerd-fonts.jetbrains-mono
  ];

  # --- ENABLE PROGRAMS FOR STYLIX ---
  # By using 'programs.x.enable', Stylix can automatically inject colors/fonts!

gtk = {
    enable = true;
    
    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyonight-gtk-theme; # <--- NEW NAME
    };

    iconTheme = {
      name = "Papirus-Dark"; # Papirus blends very well with Tokyo Night
      package = pkgs.papirus-icon-theme;
    };

    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

programs.waybar = {
    enable = true;
    
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        
        # --- Modules Layout ---
        modules-left = [
          "niri/workspaces"
          "custom/right-arrow-dark"
        ];
        
        modules-center = [
          "custom/left-arrow-dark"
          "clock#1"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "clock#2"
          "custom/right-arrow-dark"
          "custom/right-arrow-light"
          "clock#3"
          "custom/right-arrow-dark"
        ];
        
        modules-right = [
          "custom/left-arrow-dark"
          "pulseaudio"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "memory"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "cpu"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "battery"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "disk"
          "custom/left-arrow-light"
          "custom/left-arrow-dark"
          "tray"
        ];

        # --- Module Configuration ---
        "custom/left-arrow-dark" = {
          format = "";
          tooltip = false;
        };
        "custom/left-arrow-light" = {
          format = "";
          tooltip = false;
        };
        "custom/right-arrow-dark" = {
          format = "";
          tooltip = false;
        };
        "custom/right-arrow-light" = {
          format = "";
          tooltip = false;
        };

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };

        "clock#1" = {
          format = "{:%a}";
          tooltip = false;
        };
        "clock#2" = {
          format = "{:%H:%M}";
          tooltip = false;
        };
        "clock#3" = {
          format = "{:%m-%d}";
          tooltip = false;
        };

        pulseaudio = {
          format = "{icon} {volume:2}%";
          format-bluetooth = "{icon}  {volume}%";
          format-muted = "MUTE";
          format-icons = {
            headphones = "HP";
            default = ["SPK" ""];
          };
          scroll-step = 5;
          on-click = "pavucontrol";
        };

        memory = {
          interval = 5;
          format = "Mem {}%";
        };

        cpu = {
          interval = 5;
          format = "CPU {usage:2}%";
        };

        disk = {
          interval = 30;
          format = "Disk {percentage_used:2}%";
          path = "/";
        };

        tray = {
          icon-size = 20;
        };
      };
    };

    # --- CSS STYLING (From your style.css, but 'Stylix-ified') ---
 style = lib.mkForce ''
      * {
        font-size: 20px;
        font-family: "monospace";
        min-height: 0;
      }

      window#waybar {
        /*  forces these colors to override Stylix */
        font-family: "JetBrainsMono Nerd Font", "Symbols Nerd Font Mono";
	color: #fdf6e3;
      }

      /* --- Arrow Colors --- */
      #custom-right-arrow-dark,
      #custom-left-arrow-dark {
        color: #1a1a1a;
        background: transparent;
      }

      #custom-right-arrow-light,
      #custom-left-arrow-light {
        color: #292b2e;
        background: #1a1a1a;
      }

      /* --- Module Backgrounds --- */
      #workspaces,
      #clock.1,
      #clock.3,
      #pulseaudio,
      #memory,
      #cpu,
      #battery,
      #disk,
      #tray {
        background: #1a1a1a;
        color: #fdf6e3;
      }
      
      #clock.2 {
        background: #292b2e;
        color: #fdf6e3;
      }

      /* --- Workspaces --- */
      #workspaces button {
        padding: 0 2px;
        color: #fdf6e3;
      }
      #workspaces button.active {
        color: #268bd2;
      }
      #workspaces button:hover {
        box-shadow: inherit;
        text-shadow: inherit;
        background: #1a1a1a;
        border: #1a1a1a;
        padding: 0 3px;
      }

      /* --- Hardware Colors --- */
      #pulseaudio { color: #268bd2 ; }
      #memory     { color: #2aa198 ; }
      #cpu        { color: #6c71c4 ; }
      #battery    { color: #859900 ; }
      #disk       { color: #b58900 ; }

      #clock,
      #pulseaudio,
      #memory,
      #cpu,
      #battery,
      #disk {
        padding: 0 10px;
      }
    ''; 
  };
  programs.fuzzel.enable = true;
  programs.kitty.enable = true; # Stylix themes this automatically
  programs.git.enable = true;   # Stylix can even theme git!

  # Ghostty is too new for Stylix stable, so it won't be auto-themed yet.
  # You might want to use Kitty for now to test if Stylix is working.
  programs.ghostty.enable = true;

  # 2. Generate the Niri Config File
  xdg.configFile."niri/config.kdl".text = with osConfig.lib.stylix.colors.withHashtag; ''

// --- Startup ---
    // 1. Set the Wallpaper (Pulling path from System Stylix Config)
    spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-m" "fill" "-i" "${osConfig.stylix.image}"
    
    // 2. Start the Bar
    spawn-at-startup "waybar"
    
    // 3. Start XWayland support
    spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite"

    // -- Remove Pesky Window Decorations --
    prefer-no-csd
   

    // --- Input ---
    input {
        keyboard {
	 repeat-rate 35
         repeat-delay 180
            xkb {
                layout "us"
            }
        }
	mouse {
        // off
        // natural-scroll
        // accel-speed 0.2
        // accel-profile "flat"
        // scroll-method "no-scroll"
    }
 	focus-follows-mouse max-scroll-amount="0%"
 }


    // --- Layout & Styling ---
    layout {
        gaps 8
        center-focused-column "never"

        preset-column-widths {
            proportion 0.33333
            proportion 0.5
            proportion 0.66667
        }

        default-column-width { proportion 0.5; }

       // --- HERE IS THE MAGIC ---
        // We use the variables provided by Stylix here
        focus-ring {
            width 4
            active-color "${base0D}"   // This pulls the Blue from Tokyo City
            inactive-color "${base02}" // This pulls the dark grey
        }
        
        border {
            off
            width 4
            active-color "${base0E}"   // Purple
            inactive-color "${base02}"
        }
    }
       
    
 	output "DP-1" {
    		mode "5120x1440@119.99"
   		transform "normal"
    		position x=0 y=0
}
	output "DP-2" {
    	mode "2560x1440@143.856"
    	transform "90"
    	position x=5120 y=0
}

	output "HDMI-A-1" {
    	mode "2560x1440@143.856"
    	transform "normal"
    	position x=6560 y=0
}
    // --- Keybinds ---
    binds {
        // Mod is the Windows/Super key
        Mod+Shift+Slash { show-hotkey-overlay; }

        // Terminal (Ghostty)
        Mod+Return { spawn "ghostty"; }

        // Launcher (Fuzzel)
        Mod+Shift+Return { spawn "fuzzel"; }

        // Window Management
        Mod+Q repeat=false { close-window; }
        
        // Quit Niri (Logout)
        Mod+Shift+E { quit; }

        // Navigation
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Down  { focus-window-down; }
        Mod+Up    { focus-window-up; }

        // Move Windows
        Mod+Shift+Left  { move-column-left; }
        Mod+Shift+Right { move-column-right; }
        
	Mod+Ctrl+Left  { focus-monitor-left; }
    	Mod+Ctrl+Down  { focus-monitor-down; }
    	
	 Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    	Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
    	Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    	Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }

	Mod+1 { focus-workspace 1; }
    	Mod+2 { focus-workspace 2; }
    	Mod+3 { focus-workspace 3; }
    	Mod+4 { focus-workspace 4; }
    	Mod+5 { focus-workspace 5; }
    	Mod+6 { focus-workspace 6; }
    	Mod+7 { focus-workspace 7; }
    	Mod+8 { focus-workspace 8; }
    	Mod+9 { focus-workspace 9; }
    	Mod+Shift+1 { move-column-to-workspace 1; }
    	Mod+Shift+2 { move-column-to-workspace 2; }
    	Mod+Shift+3 { move-column-to-workspace 3; }
    	Mod+Shift+4 { move-column-to-workspace 4; }
    	Mod+Shift+5 { move-column-to-workspace 5; }
    	Mod+Shift+6 { move-column-to-workspace 6; }
    	Mod+Shift+7 { move-column-to-workspace 7; }
    	Mod+Shift+8 { move-column-to-workspace 8; }
    	Mod+Shift+9 { move-column-to-workspace 9; }

	Mod+Shift+R { switch-preset-window-height; }
	Mod+Ctrl+R { reset-window-height; }
    	Mod+F { maximize-column; }
    	Mod+Shift+F { fullscreen-window; }

	Mod+Ctrl+F { expand-column-to-available-width; }
	Mod+Shift+P { power-off-monitors; }
    	Mod+C { center-column; }

    	// Center all fully visible columns on screen.
    	Mod+Ctrl+C { center-visible-columns; }


        // Volume & Brightness (Requires tools like pactl or brightnessctl)
        XF86AudioRaiseVolume allow-when-locked=true { spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "+5%"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "pactl" "set-sink-volume" "@DEFAULT_SINK@" "-5%"; }
        XF86AudioMute        allow-when-locked=true { spawn "pactl" "set-sink-mute" "@DEFAULT_SINK@" "toggle"; }
    }
  '';

  # --- Shell Configuration ---
  programs.bash = {
    enable = true;
    shellAliases = {
      cat = "bat";
      v = "nvim";
      vc = "sudo nvim /etc/nixos/configuration.nix";
      rb = "sudo nixos-rebuild switch"; 
      rbu = "sudo nixos-rebuild switch --upgrade"; 
      ls = "eza --long --header --inode --sort=type --icons=auto --group-directories-first";
      cp = "xcp";
      vh = "sudo nvim /etc/nixos/home.nix";
      cud = "sudo nix-channel --update";
      vf = "sudo nvim /etc/nixos/home.nix";
    };
    
    initExtra = ''
      PS1='\[\e[38;5;35m\]\t\[\e[0m\] \[\e[92m\]|\[\e[0m\] \[\e[38;5;34m\]\w\[\e[0m\]\\$>'
    '';
  };
}
