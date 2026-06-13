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
      # Build as the user and let nixos-rebuild elevate (--sudo) only for
      # activation, instead of `sudo nixos-rebuild`. Running the whole rebuild as
      # root evaluates this git repo as root and leaves root-owned objects in
      # .git, which later breaks `nix flake update` (run as the user). Building
      # as the user keeps .git ours.
      rb = "cd /etc/nixos && nixos-rebuild switch --flake . --sudo";
      # Real upgrade for a flake system: bump flake.lock (nixpkgs, home-manager,
      # stylix), THEN rebuild from it. `--upgrade` only updates the legacy nixos
      # channel, which a flake build ignores — so it never actually moved
      # packages. flake.lock is user-owned, so `nix flake update` needs no sudo.
      rbu = "cd /etc/nixos && nix flake update && nixos-rebuild switch --flake . --sudo";
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
      rb = "cd /etc/nixos && nixos-rebuild switch --flake . --sudo";
      rbu = "cd /etc/nixos && nix flake update && nixos-rebuild switch --flake . --sudo";
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
