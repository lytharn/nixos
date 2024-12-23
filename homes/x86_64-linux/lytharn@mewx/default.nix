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

  slask.apps = {
    alacritty.enable = true;
    git.enable = true;
    mangohud.enable = true;
    tmux.enable = true;
  };

  programs.kitty = {
    enable = true;
    themeFile = "Tomorrow_Night";
  };

  programs.yazi = {
    enable = true;
    settings = {
      preview = {
        max_height = 1000;
        max_width = 1000;
      };
    };
  };

  programs.starship = {
    enable = true;
  };

  programs.eza = {
    enable = true;
    git = true;
    icons = "auto";
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "Visual Studio Dark+";
    };
  };

  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "dark_plus";
      editor = {
        cursorline = true;
        cursor-shape.insert = "bar";
      };
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
