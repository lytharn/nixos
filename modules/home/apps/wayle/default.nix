{
  lib,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.wayle;
  palette = lib.${namespace}.palette.tokyonight;
in
{
  options.${namespace}.apps.wayle = {
    enable = lib.mkEnableOption "Wayle Wayland shell (bar, notifications, OSD)";
  };

  config = lib.mkIf cfg.enable {
    services.wayle = {
      enable = true;

      # Pull in soft deps (weather/theme providers, wallpaper engine) that the
      # active config needs. open-meteo + the built-in "wayle" theme need none,
      # but leave this on so adding e.g. wallust later just works.
      autoInstallDependencies = true;

      # Config reference for all settings keys below: https://wayle.app/config/
      # (or run `wayle config schema` / `wayle config default` locally).
      settings = {
        bar.scale = 0.7;

        bar.layout = [
          {
            monitor = "*";
            show = true;
            left = [
              "hyprland-workspaces"
              "cava"
              "media"
            ];
            center = [
              "window-title"
            ];
            right = [
              "keyboard-input"
              "volume"
              "microphone"
              "cpu"
              "ram"
              "network"
              "weather"
              "clock"
              "systray"
            ];
          }
        ];

        modules = {
          clock.format = "%a %b %d  %H:%M";

          cpu = {
            border-color = "green";
            icon-bg-color = "green";
            label-color = "green";
          };

          weather = {
            location = "Linköping";
            units = "metric";
            time-format = "24h";
          };

          media = {
            format = "{{ title }} - {{ artist }}";
            players-ignored = [ "firefox" ];
          };

          # Target tray items by Id or Title using glob patterns.
          # To list the live items,
          # query the StatusNotifierWatcher for registered items:
          #   busctl --user get-property org.kde.StatusNotifierWatcher \
          #     /StatusNotifierWatcher org.kde.StatusNotifierWatcher \
          #     RegisteredStatusNotifierItems
          # Each entry is "<service>/<path>"; read its Id/Title with:
          #   busctl --user get-property <service> <path> \
          #     org.kde.StatusNotifierItem Id
          # (swap Id for Title).
          systray = {
            # Filter out tray items.
            blacklist = [ "*spotify*" ];

            # Swap app icons for wayle's bundled monochrome set, tinted with
            # the "blue" color token (resolves to styling.palette.blue below).
            # Nextcloud is deliberately left alone so its pixmap keeps
            # reflecting sync state — an override is static.
            overrides = [
              {
                name = "udiskie";
                icon = "ld-hard-drive-symbolic";
                color = "blue";
              }
              {
                name = "steam";
                icon = "si-steam-symbolic";
                color = "blue";
              }
            ];
          };
        };

        # Keys here are wayle's semantic slots; theme-provider = "wayle" derives
        # the rest of the stylesheet from these.
        styling = {
          theme-provider = "wayle";
          rounding = "sm";
          palette = {
            bg = "#${palette.bgDark}";
            surface = "#${palette.bg}"; # editor bg (bar background)
            elevated = "#${palette.bgHighlight}";
            fg = "#${palette.fg}";
            fg-muted = "#${palette.comment}";
            primary = "#${palette.blue}"; # blue accent
            red = "#${palette.red}";
            yellow = "#${palette.yellow}";
            green = "#${palette.green}";
            blue = "#${palette.blue}";
          };
        };

        # Keep hyprpaper (configured in the hyprland module) as the wallpaper
        # source; disable wayle's awww engine so the two don't fight over the
        # background layer. Flip this on (and drop hyprpaper) if you want
        # wayle's transitions/cycling — needs per-monitor connector names.
        wallpaper.engine-enabled = false;
      };
    };
  };
}
