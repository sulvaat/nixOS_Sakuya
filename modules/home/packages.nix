# Home packages (per-user).
{ config, lib, pkgs, ... }:
{
  home.packages = with pkgs; [
    swaybg
    waypaper
    xwayland-satellite
    nerd-fonts.jetbrains-mono
    # Suckless Tools
    sent      # The presentation tool
    farbfeld  # (Optional) For image support in sent
    jq
    dualsensectl # PS5 Controller
    slack
    teams-for-linux
    thunderbird
    zoom-us
    google-chrome
    davinci-resolve
    jdk
  ];
}
