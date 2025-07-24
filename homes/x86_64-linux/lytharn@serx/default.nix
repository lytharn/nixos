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

  # Enable internal modules
  slask.apps = {
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    git.enable = true;
    helix.enable = true;
    starship.enable = true;
    tmux.enable = true;
  };

  home.stateVersion = "25.05"; # DO NOT TOUCH

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
