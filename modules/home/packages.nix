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
 #   thunderbird
    zoom-us
    google-chrome
#    davinci-resolve
    jdk
  ];

  # Teams for Linux defaults followSystemTheme to true, which forces the web
  # app to follow the OS color-scheme via the freedesktop appearance portal.
  # niri has no portal reliably reporting dark, so the theme is a coin-flip at
  # startup and the in-app theme picker gets locked. Disabling it lets Teams
  # keep its own theme: pick Dark once in-app and it sticks.
  xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
    followSystemTheme = false;
  };
}
