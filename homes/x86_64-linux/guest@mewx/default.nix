{
  config,
  pkgs,
  lib,
  namespace, # Waiting for https://github.com/snowfallorg/lib/pull/147
  ...
}:

{
  home.username = "guest";
  home.homeDirectory = "/home/guest";

  # Set keyboard layouts
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      show-all-sources = true;
      sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "se"
        ])
      ];
    };
  };

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
