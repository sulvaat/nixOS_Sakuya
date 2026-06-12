# Shells and prompt: fish, bash, starship.
{ config, pkgs, lib, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting
    '';
    shellAliases = {
      cat = "bat";
      y = "yazi";
      v = "nvim";
      vc = "sudo nvim /etc/nixos/configuration.nix";
      vh = "sudo nvim /etc/nixos/home.nix";
      rb = "cd /etc/nixos && sudo nixos-rebuild switch --flake .";
      rbu = "cd /etc/nixos && sudo nixos-rebuild switch --flake . --upgrade";
      # Garbage cleanup: keep the 3 newest system generations, collect store
      # garbage, then refresh the boot menu so the pruned generations drop off.
      gc = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +3 && sudo nix-collect-garbage && sudo /run/current-system/bin/switch-to-configuration boot";
      ls = "eza --long --header --inode --sort=type --icons=auto --group-directories-first";
      cp = "xcp";
      cud = "sudo nix-channel --update";
      vf = "sudo nvim /etc/nixos/home.nix";
      ns = "nix search nixpkgs";
    };
    plugins = [
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      { name = "done"; src = pkgs.fishPlugins.done.src; }
      { name = "fzf-fish"; src = pkgs.fishPlugins.fzf-fish.src; }
      { name = "forgit"; src = pkgs.fishPlugins.forgit.src; }
    ];
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      cat = "bat";
      v = "nvim";
      vc = "sudo nvim /etc/nixos/configuration.nix";
      rb = "sudo nixos-rebuild switch";
      rbu = "sudo nixos-rebuild switch --upgrade";
      gc = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +3 && sudo nix-collect-garbage && sudo /run/current-system/bin/switch-to-configuration boot";
      ls = "eza --long --header --inode --sort=type --icons=auto --group-directories-first";
      cp = "xcp";
      vh = "sudo nvim /etc/nixos/home.nix";
      cud = "sudo nix-channel --update";
      vf = "sudo nvim /etc/nixos/home.nix";
      ns = "nix search nixpkgs";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      scan_timeout = 50;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };
}
