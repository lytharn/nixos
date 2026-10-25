{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.noctalia;
  # Import the theme palette directly from lib/palette (nothing injects it as lib.${namespace}).
  palette = (import ../../../../lib/palette { }).palette.tokyonight;
  hex = c: "#${c}";
in
{
  options.${namespace}.apps.noctalia = {
    enable = lib.mkEnableOption "Noctalia Wayland shell (bar, notifications, OSD)";

    calendarPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/run/secrets/noctalia-calendar";
      description = ''
        Path to a file holding a Nextcloud app password. When set, Noctalia syncs every
        Nextcloud calendar over CalDAV into the control-center calendar. Supplied by the caller
        (a clan var) so the password never lands in the Nix store.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.noctalia = {
      enable = true;
      systemd.enable = true;

      # Rendered to ~/.config/noctalia/palettes/tokyonight.json; selected below by
      # theme.custom_palette. Roles: https://docs.noctalia.dev/noctalia/theming/palette/
      customPalettes.tokyonight.dark = {
        mPrimary = hex palette.blue;
        mOnPrimary = hex palette.bgDark;
        mSecondary = hex palette.magenta;
        mOnSecondary = hex palette.bgDark;
        mTertiary = hex palette.green;
        mOnTertiary = hex palette.bgDark;
        mError = hex palette.red;
        mOnError = hex palette.bgDark;
        mSurface = hex palette.bg; # editor bg (bar background)
        mOnSurface = hex palette.fg;
        mSurfaceVariant = hex palette.bgHighlight;
        mOnSurfaceVariant = hex palette.fgDark;
        mOutline = hex palette.fgGutter;
        mShadow = hex palette.bgDark;
        mHover = hex palette.bgVisual;
        mOnHover = hex palette.fg;
        terminal = {
          background = hex palette.bg;
          foreground = hex palette.fg;
          cursor = hex palette.fg;
          cursorText = hex palette.bg;
          selectionBg = hex palette.bgVisual;
          selectionFg = hex palette.fg;
          normal = {
            black = hex palette.bgDark;
            red = hex palette.red;
            green = hex palette.green;
            yellow = hex palette.yellow;
            blue = hex palette.blue;
            magenta = hex palette.magenta;
            cyan = hex palette.cyan;
            white = hex palette.fgDark;
          };
          bright = {
            black = hex palette.terminalBlack;
            red = hex palette.red;
            green = hex palette.green;
            yellow = hex palette.yellow;
            blue = hex palette.blue;
            magenta = hex palette.magenta;
            cyan = hex palette.cyan;
            white = hex palette.fg;
          };
        };
      };

      # Config reference: https://docs.noctalia.dev/noctalia/configuration/ (or the upstream
      # example.toml, which lists every key at its default). Validated at build time
      # (programs.noctalia.checkConfig). Changes made in the settings GUI override these at
      # runtime until the next deploy rewrites the file.
      settings = {
        theme = {
          mode = "dark";
          source = "custom";
          custom_palette = "tokyonight";
        };

        # Keep hyprpaper (configured in the hyprland module) as the wallpaper source.
        wallpaper.enabled = false;

        # The week starts on the LC_TIME locale's first weekday (sv_SE → Monday).
        control_center.calendar.show_week_numbers = true;

        # Read-only CalDAV sync (every 15 min by default). Accounts added in the settings GUI
        # (e.g. ICS subscriptions) go to settings.toml, which deploys don't overwrite.
        calendar = lib.mkIf (cfg.calendarPasswordFile != null) {
          enabled = true;
          account.home_nextcloud = {
            type = "caldav";
            name = "Nextcloud";
            provider = "custom";
            server_url = "https://cloud.gate-catla.ts.net/remote.php/dav/";
            username = "lytharn";
            calendars = [ ]; # all discovered calendars
            credential_source = "file";
            password_file = cfg.calendarPasswordFile;
          };
        };

        weather = {
          enabled = true;
          unit = "celsius"; # wind is always km/h; there is no m/s option
        };
        # Geocoded; feeds weather (and night light / auto theme mode).
        location.address = "Linköping";

        shell.mpris.blacklist = [ "firefox" ];

        bar.main = {
          start = [
            "workspaces"
            "audio_visualizer"
            "media"
          ];
          center = [ "active_window" ];
          end = [
            "keyboard_layout"
            "volume"
            "mic"
            "cpu"
            "ram"
            "network"
            "weather"
            "clock" # click opens the calendar
            "tray"
            "notifications"
          ];
          # A pill background behind each widget (palette.bgHighlight).
          capsule = true;
          capsule_fill = "surface_variant";
        };

        # Named widget instances: `type` picks the widget, the rest are its settings.
        # Widgets default to plain on_surface text; `color` tints icon + label. The palette
        # has only three accent roles, so the rest are fixed hex from lib/palette.
        widget = {
          audio_visualizer.color = hex palette.magenta;
          media.color = hex palette.green1;
          keyboard_layout.color = hex palette.teal;
          volume.color = hex palette.blue;
          mic = {
            type = "volume";
            device = "input";
            color = hex palette.cyan;
          };
          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
            color = hex palette.green;
          };
          ram = {
            type = "sysmon";
            stat = "ram_pct";
            color = hex palette.yellow;
          };
          network.color = hex palette.purple;
          weather.color = hex palette.orange;
          clock = {
            format = "{:%a %b %d  %H:%M}";
            color = hex palette.blue;
          };
          # Matched against each item's id/title/bus name etc. (exact, no globs).
          tray.hidden = [ "spotify" ];
        };
      };
    };
  };
}
