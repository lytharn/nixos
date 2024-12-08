{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "lytharn";
  home.homeDirectory = "/home/lytharn";

  # Packages that should be installed to the user profile.
  home.packages = [ pkgs.htop ];

  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      exec-once = [
        "waybar"
        "hyprpaper"
        "swayidle -w timeout 10 'if pgrep -x swaylock; then hyprctl dispatch dpms off; fi' resume 'hyprctl dispatch dpms on' before-sleep 'loginctl lock-session $XDG_SESSION_ID' lock 'swaylock -f'"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      ];
      general = {
        border_size = 2;
        "col.active_border" = "rgba(fb3c67ff) rgba(1f5d8dff) 45deg";
      };
      decoration = {
        rounding = 5;
        shadow_offset = "0 5";
        "col.shadow" = "rgba(00000099)";
      };
      input = {
        kb_layout = "us,se";
      };
      windowrulev2 = [
        # Context menu fix for steam
        "stayfocused, title:^()$,class:^(steam)$"
        "minsize 1 1, title:^()$,class:^(steam)$"
        # No freeze fix for steam
        "noblur, class:^(steam)$"
        "forcergbx, class:^(steam)$"
      ];
      "$mod" = "SUPER";
      bind = [
        "$mod, O, exec, firefox"
        "$mod, Q, killactive"
        "$mod, T, togglefloating"
        "$mod, F, fullscreen"
        "$mod CTRL, F, fullscreenstate, -1 2"
        "$mod, RETURN, exec, alacritty"
        "$mod CTRL, Q, exec, wlogout"
        "$mod, D, exec, fuzzel"
        "$mod, SPACE, exec, hyprctl switchxkblayout corsair-corsair-k70-rgb-tkl-champion-series-mechanical-gaming-keyboard next"
        "$mod, PRINT, exec, cd /home/lytharn/Pictures; wayshot"
        "$mod, N, exec, kitty yazi"
        "$mod, F1, exec, systemctl suspend"
        "$mod, F2, exec, loginctl lock-session $XDG_SESSION_ID"
        "$mod, F5, exec, systemctl reboot"
        "$mod, F9, exec, systemctl poweroff"
        "$mod, L, movefocus, r"
        "$mod, H, movefocus, l"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        "$mod SHIFT, L, swapwindow, r"
        "$mod SHIFT, H, swapwindow, l"
        "$mod SHIFT, K, swapwindow, u"
        "$mod SHIFT, J, swapwindow, d"
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod, 6, workspace, 6"
        "$mod, 7, workspace, 7"
        "$mod, 8, workspace, 8"
        "$mod, 9, workspace, 9"
        "$mod, 0, workspace, 0"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
        "$mod SHIFT, 6, movetoworkspace, 6"
        "$mod SHIFT, 7, movetoworkspace, 7"
        "$mod SHIFT, 8, movetoworkspace, 8"
        "$mod SHIFT, 9, movetoworkspace, 9"
        "$mod SHIFT, 0, movetoworkspace, 0"
      ];
      bindm = [
        # mouse movements
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
        "$mod ALT, mouse:272, resizewindow"
      ];
      bindl = [
        # Locked, aka. works also when an input inhibitor (e.g. a lockscreen) is active.
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+" # Volume limited to 100%
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioPlay, exec, playerctl --player=spotify,%any play-pause"
        ",XF86AudioStop, exec, playerctl --player=spotify,%any stop"
        ",XF86AudioNext, exec, playerctl --player=spotify,%any next"
        ",XF86AudioPrev, exec, playerctl --player=spotify,%any previous"
      ];
    };
  };

  programs.waybar = {
    enable = true;
    settings = {
      mainBar = {
        modules-left = [
          "hyprland/workspaces"
          "hyprland/submap"
        ];
        modules-center = [ "hyprland/window" ];
        modules-right = [
          "mpris"
          "idle_inhibitor"
          "hyprland/language"
          "wireplumber"
          "cpu"
          "memory"
          "clock"
          "tray"
        ];
        mpris = {
          ignored-players = [ "firefox" ];
        };
        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };
      };
    };
  };

  programs.wlogout = {
    enable = true;
  };

  programs.fuzzel = {
    enable = true;
  };

  services.mako = {
    enable = true;
    backgroundColor = "#162633FF";
    borderRadius = 5;
    defaultTimeout = 2000;
    width = 500;
  };

  services.udiskie.enable = true; # Auto mount removable disks

  programs.swaylock = {
    enable = true;
    settings = {
      image = "/home/lytharn/Dropbox/wallpapers/astronaut-landscape-sci-fi-city.jpg";
      ignore-empty-password = true;
    };
  };

  xdg.configFile."hypr/hyprpaper.conf".text = ''
    preload = /home/lytharn/Dropbox/wallpapers/road-scenery.jpg

    #set the default wallpaper(s) seen on inital workspace(s) --depending on the number of monitors used
    wallpaper = ,/home/lytharn/Dropbox/wallpapers/road-scenery.jpg
  '';

  programs.mangohud = {
    enable = true;
    enableSessionWide = true;
    settings = {
      fps_only = true;
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
      terminal.shell = {
        program = "/usr/bin/env";
        args = [
          "bash"
          "-l"
          "-c"
          "tmux attach || tmux"
        ];
      };
      window = {
        startup_mode = "Maximized";
        padding.x = 10;
        padding.y = 10;
      };
      font.normal = {
        family = "Hack Nerd Font";
        style = "Regular";
      };
    };
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

  programs.fish = {
    enable = true;
    functions = {
      fish_greeting = "fastfetch";
      # Start nix-shell with fish without greeting if available, otherwise start bash which is always available, even in a pure nix-shell.
      nix-shell = ''command nix-shell --run 'if type fish &> /dev/null; then fish -C "functions -e fish_greeting"; else bash; fi' $argv'';
    };
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
