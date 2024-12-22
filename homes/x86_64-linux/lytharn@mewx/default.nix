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

  programs.mangohud = {
    enable = true;
    enableSessionWide = true;
    settings = {
      fps_only = true;
    };
  };

  slask.apps = {
    alacritty.enable = true;
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

  programs.git = {
    enable = true;
    aliases = {
      co = "checkout";
      cp = "cherry-pick";
      st = "status";
      amend = "commit --amend --no-edit";
      l = "log --graph --pretty=customone";
      lt = "log --graph --pretty=customone --first-parent";
      ltr = "log -15 --reverse --pretty=customone --first-parent";
      ll = "log --graph --pretty=customfull";
      rl = "reflog --pretty=customref";
      rll = "reflog --pretty=customreffull";
    };
    userEmail = "lytharn@users.noreply.github.com";
    userName = "lytharn";
    difftastic.enable = true;
    extraConfig = {
      core = {
        editor = "nvim";
      };
      merge = {
        conflictstyle = "diff3";
      };
      pretty = {
        customone = "format:%C(yellow)%h %C(reset)%s %C(blue)%an %C(green)(%cr) %C(magenta)%d";
        customfull = "format:Commit: %C(yellow)%H %C(magenta)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
        customrefone = "format:%C(yellow)%h %C(magenta)%gd %C(reset)%s %C(green)(%cr) %C(magenta)%d";
        customreffull = "format:Selector: %C(magenta)%gD%nCommit: %C(yellow)%H %C(magenta)%d%nAuthor: %C(bold blue)'%an' <%ae> %C(bold green)(%ai)%nCommitter: %C(blue)'%cn' <%ce> %C(green)(%ci)%n%B";
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
