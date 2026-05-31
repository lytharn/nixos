{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.hyprland;
in
{
  options.${namespace}.apps.hyprland = {
    enable = lib.mkEnableOption "Hyprland desktop environment";

    wallpaper = lib.mkOption {
      type = lib.types.str;
      description = "Path to the hyprpaper wallpaper image.";
    };

    swaylockImage = lib.mkOption {
      type = lib.types.str;
      description = "Path to the swaylock background image.";
    };

    kbLayout = lib.mkOption {
      type = lib.types.str;
      default = "us";
      description = "Value for Hyprland's input.kb_layout.";
    };

    keyboardSwitchDevice = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Hyprland device name used by the SUPER+SPACE layout switcher
        (see `hyprctl devices`). If null, the binding is omitted.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang"; # Todo change to lua config
      settings = {
        exec-once = [
          "waybar"
          "hyprpaper"
          "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        ];
        general = {
          border_size = 2;
          "col.active_border" = "rgba(fb3c67ff) rgba(1f5d8dff) 45deg";
        };
        decoration = {
          rounding = 5;
        };
        input = {
          kb_layout = cfg.kbLayout;
        };
        "$mod" = "SUPER";
        bind = [
          "$mod, M, exec, firefox"
          "$mod, Q, killactive"
          "$mod, T, togglefloating"
          "$mod, F, fullscreen"
          "$mod CTRL, F, fullscreenstate, -1 2"
          "$mod, RETURN, exec, alacritty"
          "$mod CTRL, Q, exec, wlogout"
          "$mod, D, exec, fuzzel"
          "$mod, PRINT, exec, cd ${config.home.homeDirectory}/Pictures; wayshot"
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
          "$mod, U, workspace, 1"
          "$mod, I, workspace, 2"
          "$mod, O, workspace, 3"
          "$mod, P, workspace, 4"
          "$mod, Y, workspace, 5"
          "$mod, 6, workspace, 6"
          "$mod, 7, workspace, 7"
          "$mod, 8, workspace, 8"
          "$mod, 9, workspace, 9"
          "$mod, 0, workspace, 0"
          "$mod SHIFT, U, movetoworkspace, 1"
          "$mod SHIFT, I, movetoworkspace, 2"
          "$mod SHIFT, O, movetoworkspace, 3"
          "$mod SHIFT, P, movetoworkspace, 4"
          "$mod SHIFT, Y, movetoworkspace, 5"
          "$mod SHIFT, 6, movetoworkspace, 6"
          "$mod SHIFT, 7, movetoworkspace, 7"
          "$mod SHIFT, 8, movetoworkspace, 8"
          "$mod SHIFT, 9, movetoworkspace, 9"
          "$mod SHIFT, 0, movetoworkspace, 0"
        ]
        ++ lib.optional (
          cfg.keyboardSwitchDevice != null
        ) "$mod, SPACE, exec, hyprctl switchxkblayout ${cfg.keyboardSwitchDevice} next";
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

    services.hyprpaper = {
      enable = true;
      settings = {
        ipc = true; # Enables: hyprctl hyprpaper wallpaper '[mon], [path], [fit_mode]'
        splash = false;
        wallpaper = {
          monitor = "";
          path = cfg.wallpaper;
          fit_mode = "cover";
        };
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
              activated = "";
              deactivated = "";
            };
          };
        };
      };
    };

    programs.wlogout.enable = true;

    programs.fuzzel.enable = true;

    services.mako = {
      enable = true;
      settings = {
        background-color = "#162633FF";
        border-radius = 5;
        default-timeout = 2000;
        width = 500;
      };
    };

    services.udiskie.enable = true; # Auto mount removable disks

    programs.swaylock = {
      enable = true;
      settings = {
        image = cfg.swaylockImage;
        ignore-empty-password = true;
      };
    };
  };
}
