{
  pkgs,
  inputs,
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  sops.defaultSopsFile = inputs.self + /secrets/mewx/secrets.yaml;

  # Packages that should be installed to the user profile.
  home.packages = [ pkgs.htop ];

  # Enable internal modules
  slask.apps = {
    bat.enable = true;
    claude.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fzf.enable = true;
    gh.enable = true;
    ghostty.enable = true;
    git.enable = true;
    helix.enable = true;
    hyprland = {
      enable = true;
      wallpaper = "/home/lytharn/Nextcloud/wallpapers/road-scenery.jpg";
      swaylockImage = "/home/lytharn/Nextcloud/wallpapers/astronaut-landscape-sci-fi-city.jpg";
      kbLayout = "us,se";
    };
    mangohud.enable = true;
    nextcloud-client.enable = true;
    starship.enable = true;
    tmux.enable = true;
    wayle.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
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
