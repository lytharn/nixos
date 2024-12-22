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

  slask.apps.alacritty.enable = true;

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

  programs.tmux = {
    enable = true;
    aggressiveResize = true;
    baseIndex = 1;
    clock24 = true;
    escapeTime = 0;
    historyLimit = 100000;
    prefix = "C-a";
    sensibleOnTop = true;
    shell = "${pkgs.fish}/bin/fish";
    terminal = "tmux-256color";
    plugins = with pkgs; [ tmuxPlugins.pain-control ];
    extraConfig = ''
      # Set vi copy mode
      setw -g mode-keys vi

      # Fix true color support
      set-option -sa terminal-overrides ',alacritty:RGB'

      # Set status line
      set -g status-justify "left"
      set -g status "on"
      set -g status-left-style "none"
      set -g message-command-style "fg=colour0,bg=colour4"
      set -g status-right-style "none"
      set -g pane-active-border-style "fg=colour6"
      set -g status-style "none,bg=colour8"
      set -g message-style "fg=colour0,bg=colour4"
      set -g pane-border-style "fg=colour4"
      set -g status-right-length "100"
      set -g status-left-length "100"
      setw -g window-status-activity-style "none"
      setw -g window-status-separator ""
      setw -g window-status-style "none,fg=colour7,bg=colour8"
      set -g status-left "#[fg=colour0,bg=colour6] #S #[fg=colour6,bg=colour8]"
      set -g status-right "#[fg=colour4,bg=colour8]#[fg=colour0,bg=colour4] %Y-%m-%d  %H:%M #[fg=colour6,bg=colour4]#[fg=colour0,bg=colour6] #h "
      setw -g window-status-format "#[fg=colour7,bg=colour8] #I #[fg=colour7,bg=colour8] #W "
      setw -g window-status-current-format "#[fg=colour8,bg=colour4]#[fg=colour0,bg=colour4] #I #[fg=colour0,bg=colour4] #W #[fg=colour4,bg=colour8]"

      # Keybindings
      bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel
      bind-key -T copy-mode-vi v send-keys -X begin-selection
    '';
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
