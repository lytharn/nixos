{
  config,
  pkgs,
  lib,
  namespace, # Waiting for https://github.com/snowfallorg/lib/pull/147
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  # Packages that should be installed to the user profile.
  home.packages = [ pkgs.htop ];

  # Enable internal modules
  slask.apps = {
    alacritty.enable = true;
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    git.enable = true;
    helix.enable = true;
    kitty.enable = true;
    mangohud.enable = true;
    starship.enable = true;
    tmux.enable = true;
    yazi.enable = true;
  };

  services.dropbox.enable = true;

  # Set keyboard layouts
  dconf.settings = {
    "org/gnome/desktop/input-sources" = {
      show-all-sources = true;
      sources = [
        (lib.hm.gvariant.mkTuple [
          "xkb"
          "us"
        ])
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
