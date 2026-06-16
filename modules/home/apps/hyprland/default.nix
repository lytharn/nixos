{
  config,
  lib,
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

    scale = lib.mkOption {
      type = lib.types.str;
      default = "auto";
      description = ''
        Scale for the catch-all monitor rule. "auto" lets Hyprland pick
        (its heuristic applies fractional scaling on high-DPI panels); set
        an explicit value like "1" or "1.25" to override.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      # UWSM owns the session (see the NixOS hyprland module's withUWSM), so
      # let it manage graphical-session.target instead of Home Manager's
      # hyprland-session.target. UWSM finalizes the compositor environment.
      systemd.enable = false;
      extraConfig =
        lib.replaceStrings
          [
            "@kbLayout@"
            "@picturesDir@"
            "@scale@"
          ]
          [
            cfg.kbLayout
            "${config.home.homeDirectory}/Pictures"
            cfg.scale
          ]
          (builtins.readFile ./hyprland.lua);
    };

    # Autostarted as a systemd user service bound to graphical-session.target,
    # which UWSM pulls in.
    services.polkit-gnome.enable = true;

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

    programs.wlogout.enable = true;

    programs.fuzzel.enable = true;

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
