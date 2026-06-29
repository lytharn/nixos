{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.hyprland;
  palette = lib.${namespace}.palette.tokyonight;
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
            "@colRed@"
            "@colBlue@"
            "@colComment@"
          ]
          [
            cfg.kbLayout
            "${config.home.homeDirectory}/Pictures"
            cfg.scale
            palette.red
            palette.blue
            palette.comment
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

    # Graceful logout/shutdown GUI: asks apps to exit cleanly before quitting
    # Hyprland, then runs the optional --post-cmd (see binds in hyprland.lua).
    home.packages = [ pkgs.hyprshutdown ];

    # Application launcher
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "Hack Nerd Font:size=12";
          lines = 10;
          width = 35;
          horizontal-pad = 20;
          vertical-pad = 12;
        };
        # Match Hyprland's window border geometry (border_size=2, rounding=5
        # in hyprland.lua). Fuzzel has no gradient support.
        border = {
          radius = 5;
          width = 2;
        };
        # Fuzzel uses RRGGBBAA hex; the background alpha gives the semi-transparent
        # panel, "ff" is fully opaque.
        colors = {
          background = "${palette.bg}e6"; # ~90% opaque
          text = "${palette.fg}ff";
          match = "${palette.blue}ff";
          selection = "${palette.bgHighlight}ff";
          selection-text = "${palette.fg}ff";
          selection-match = "${palette.blue}ff";
          border = "${palette.blue}ff";
        };
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

    # Listens for logind's lock signal (emitted by the Mod+F2 bind's
    # `loginctl lock-session`) and runs swaylock; also locks before suspend.
    # Runs as a systemd user service bound to graphical-session.target.
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof swaylock || swaylock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
      };
    };
  };
}
