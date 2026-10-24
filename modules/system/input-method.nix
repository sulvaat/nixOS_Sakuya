# Japanese input via fcitx5 + Mozc.
#
# Toggle between direct (English) and Japanese with Ctrl+Space (fcitx5's default
# trigger). The default input-method group is seeded in
# modules/home/input-method.nix so Mozc is available on first launch, and niri
# autostarts the daemon (see modules/home/niri.nix, the @fcitx5@ token).
#
# waylandFrontend = true makes fcitx5 use the Wayland text-input protocol, which
# niri implements — so native Wayland apps get IME without GTK_IM_MODULE/
# QT_IM_MODULE hacks. XWayland apps fall back via fcitx5's X11 frontend.
{ pkgs, ... }:
{
  # Workaround (2026-10): Qt's newer `uic` rejects class names with a leading
  # "::", and mozc's dictionary_tool.ui uses "::mozc::gui::DictionaryContentTableWidget",
  # so mozc (and fcitx5-mozc, which depends on it) fails to build from nixpkgs
  # 2026-10-20 on. Strip the leading "::". The sed only matches that form, so it
  # becomes a no-op once upstream fixes the file. Remove when nixpkgs builds
  # mozc again.
  nixpkgs.overlays = [
    (final: prev: {
      mozc = prev.mozc.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i 's/\([">]\)::mozc::/\1mozc::/g' src/gui/dictionary_tool/dictionary_tool.ui
        '';
      });
    })
  ];

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-mozc ];
      waylandFrontend = true;
    };
  };
}
