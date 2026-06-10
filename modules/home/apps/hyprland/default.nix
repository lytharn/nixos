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
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      extraConfig =
        lib.replaceStrings
          [
            "@kbLayout@"
            "@polkitAgent@"
            "@picturesDir@"
          ]
          [
            cfg.kbLayout
            "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
            "${config.home.homeDirectory}/Pictures"
          ]
          (builtins.readFile ./hyprland.lua);
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
