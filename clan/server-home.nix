# Shared Home-Manager profile for the headless servers: a minimal shell toolkit.
{
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  slask.apps = {
    bat.enable = true;
    direnv.enable = true;
    eza.enable = true;
    fish.enable = true;
    fzf.enable = true;
    git.enable = true;
    helix.enable = true;
    starship.enable = true;
    tmux.enable = true;
    zoxide.enable = true;
  };

  home.stateVersion = "25.05"; # DO NOT TOUCH
  programs.home-manager.enable = true;
}
