# Always-local two-way sync under ~/Nextcloud for the few folders that must stay current
# (the KeePassXC database, Notes); pick them with the client's selective sync. Everything
# else stays on-demand via the rclone mount (rclone-nextcloud, ~/Nextcloud-remote). The
# account login is a one-off in the client's GUI.
{
  lib,
  pkgs,
  config,
  namespace,
  ...
}:
let
  cfg = config.${namespace}.apps.nextcloud-client;
in
{
  options.${namespace}.apps.nextcloud-client = {
    enable = lib.mkEnableOption "nextcloud-client";
  };

  config = lib.mkIf cfg.enable {
    services.nextcloud-client = {
      enable = true;
      startInBackground = true;
    };
    # The systemd service above starts the client. Its own "Launch on system startup" (on by
    # default) would add a second instance via ~/.config/autostart, and the two race at login
    # and both exit; the desktops' read-only autostart dir (clan/desktop-home.nix) prevents it.
    home.packages = [ pkgs.nextcloud-client ];
  };
}
